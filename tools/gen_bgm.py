# -*- coding: utf-8 -*-
"""
BGM 程序化合成器
为 7 个区域 + 主菜单/城镇 各合成一首循环 BGM, 输出到 project/src/assets/audio/bgm/

依赖: numpy + scipy + ffmpeg (PATH 中)
设计:
  - 每首 60-90 秒, 末端淡出 0 拍以便无缝循环
  - ADSR 包络 + 简易和弦进行 + 区域风味打击垫
  - 直接生成 wav, 调用 ffmpeg 转 ogg, 删除 wav
"""

import os
import sys
import math
import struct
import wave
import subprocess
import shutil

import numpy as np
from scipy import signal as sp_signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BGM_DIR = os.path.join(ROOT, "project", "src", "assets", "audio", "bgm")
SFX_DIR = os.path.join(ROOT, "project", "src", "assets", "audio", "sfx")

SR = 44100  # 采样率


# --------------------------- 基础合成单元 ---------------------------

def adsr(n_samples, attack=0.01, decay=0.1, sustain=0.7, release=0.1):
    """ADSR 包络"""
    a = int(n_samples * attack)
    d = int(n_samples * decay)
    r = int(n_samples * release)
    s = max(0, n_samples - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, max(1, a)),
        np.linspace(1, sustain, max(1, d)),
        np.full(s, sustain),
        np.linspace(sustain, 0, max(1, r)),
    ])
    if env.size < n_samples:
        env = np.pad(env, (0, n_samples - env.size))
    return env[:n_samples]


def tone(freq, dur, wave_type="sine", amp=0.3, env=None, detune=0.0):
    """单音生成"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + detune)
    if wave_type == "sine":
        x = np.sin(2 * np.pi * f * t)
    elif wave_type == "saw":
        x = sp_signal.sawtooth(2 * np.pi * f * t)
    elif wave_type == "square":
        x = sp_signal.square(2 * np.pi * f * t, duty=0.5)
    elif wave_type == "triangle":
        x = sp_signal.sawtooth(2 * np.pi * f * t, width=0.5)
    elif wave_type == "noise":
        x = np.random.uniform(-1, 1, n)
    else:
        x = np.sin(2 * np.pi * f * t)
    if env is None:
        env = adsr(n)
    return x * env * amp


def chord(freqs, dur, wave_type="sine", amp=0.2, env=None):
    """合奏多音 = 和弦"""
    n = int(dur * SR)
    out = np.zeros(n)
    for f in freqs:
        out += tone(f, dur, wave_type, amp / max(1, len(freqs)), env)
    return out


def lowpass(x, cutoff_hz=2000):
    """低通滤波,让合成音不那么刺耳"""
    sos = sp_signal.butter(4, cutoff_hz / (SR / 2), output="sos")
    return sp_signal.sosfilt(sos, x)


def reverb(x, decay=0.4, taps=12):
    """简易梳状混响 (haas + 衰减回声)"""
    out = x.copy()
    for i in range(1, taps + 1):
        delay = int(SR * 0.04 * i)
        if delay >= len(x):
            break
        gain = decay ** i
        if delay > 0:
            out[delay:] += x[:-delay] * gain
    # 归一化
    peak = np.max(np.abs(out)) or 1.0
    return out / peak * 0.85


def mix(*tracks, weights=None):
    """多轨混音"""
    n = max(len(t) for t in tracks)
    out = np.zeros(n)
    if weights is None:
        weights = [1.0] * len(tracks)
    for t, w in zip(tracks, weights):
        out[: len(t)] += t * w
    peak = np.max(np.abs(out)) or 1.0
    return out / peak * 0.9


def loop_fade_seam(x, fade_sec=2.0):
    """让首尾衔接顺滑(避免循环点爆音)"""
    n = int(fade_sec * SR)
    if len(x) <= 2 * n:
        return x
    fade_in = np.linspace(0, 1, n)
    fade_out = np.linspace(1, 0, n)
    head = x[:n].copy() * fade_in
    tail = x[-n:].copy() * fade_out
    cross = head + tail
    out = x.copy()
    out[:n] = cross
    out[-n:] = 0  # 末尾静音, 留给循环回到头部
    return out


# --------------------------- 音乐理论辅助 ---------------------------

A4 = 440.0


def note(name, octave=4):
    """音名→频率. 例如 note('A', 4) = 440"""
    semitones = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6,
                 "E": -5, "F": -4, "F#": -3, "Gb": -3, "G": -2, "G#": -1,
                 "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}
    s = semitones[name]
    return A4 * (2 ** ((s + (octave - 4) * 12) / 12.0))


def chord_freqs(root, kind="min"):
    """三和弦/七和弦"""
    intervals = {
        "maj": [0, 4, 7],
        "min": [0, 3, 7],
        "dim": [0, 3, 6],
        "sus": [0, 5, 7],
        "min7": [0, 3, 7, 10],
        "maj7": [0, 4, 7, 11],
    }
    return [root * (2 ** (i / 12.0)) for i in intervals[kind]]


# --------------------------- 区域曲风模板 ---------------------------

REGION_PRESETS = {
    "crypt": {
        # 暗黑墓穴: Am 自然小调, 慢速, 低频管风琴感
        "key_root": note("A", 2),
        "tempo": 70,
        "progression": [("min", 0), ("min", -3), ("maj", -5), ("min", -7)],  # i bIII bVI v
        "lead_wave": "triangle",
        "pad_wave": "sine",
        "lead_octave_offset": 24,
        "pad_octave_offset": 0,
        "lp_cutoff": 1400,
        "reverb_decay": 0.55,
        "duration": 70,
    },
    "swamp": {
        # 腐沼: D 多利安, 中速, 沉郁
        "key_root": note("D", 2),
        "tempo": 84,
        "progression": [("min", 0), ("min7", -2), ("maj", -4), ("min", -7)],
        "lead_wave": "saw",
        "pad_wave": "triangle",
        "lead_octave_offset": 12,
        "pad_octave_offset": 0,
        "lp_cutoff": 1200,
        "reverb_decay": 0.5,
        "duration": 70,
    },
    "forge": {
        # 熔炉: E phrygian, 中快速, 金属感
        "key_root": note("E", 2),
        "tempo": 110,
        "progression": [("min", 0), ("maj", 1), ("maj", -4), ("min", -7)],
        "lead_wave": "saw",
        "pad_wave": "square",
        "lead_octave_offset": 12,
        "pad_octave_offset": 0,
        "lp_cutoff": 2400,
        "reverb_decay": 0.35,
        "duration": 75,
    },
    "ice": {
        # 冰封: F# min, 慢速, 空灵
        "key_root": note("F#", 2),
        "tempo": 65,
        "progression": [("min", 0), ("maj", 5), ("maj", 7), ("min", -3)],
        "lead_wave": "sine",
        "pad_wave": "sine",
        "lead_octave_offset": 24,
        "pad_octave_offset": 0,
        "lp_cutoff": 3200,
        "reverb_decay": 0.7,
        "duration": 80,
    },
    "void": {
        # 虚空: 不和谐音程, 缓慢呼吸
        "key_root": note("C", 2),
        "tempo": 60,
        "progression": [("dim", 0), ("min", 6), ("dim", 3), ("min7", -1)],
        "lead_wave": "saw",
        "pad_wave": "sine",
        "lead_octave_offset": 12,
        "pad_octave_offset": 0,
        "lp_cutoff": 1800,
        "reverb_decay": 0.65,
        "duration": 80,
    },
    "field": {
        # 野外: G major, 明快进行曲
        "key_root": note("G", 2),
        "tempo": 100,
        "progression": [("maj", 0), ("maj", 7), ("min", 9), ("maj", 5)],  # I V vi IV
        "lead_wave": "triangle",
        "pad_wave": "sine",
        "lead_octave_offset": 12,
        "pad_octave_offset": 0,
        "lp_cutoff": 2800,
        "reverb_decay": 0.4,
        "duration": 65,
    },
    "town": {
        # 城镇: C major, 安宁
        "key_root": note("C", 3),
        "tempo": 80,
        "progression": [("maj", 0), ("maj", 5), ("min", 9), ("maj", 7)],
        "lead_wave": "triangle",
        "pad_wave": "sine",
        "lead_octave_offset": 12,
        "pad_octave_offset": 0,
        "lp_cutoff": 3000,
        "reverb_decay": 0.45,
        "duration": 60,
    },
    "menu": {
        # 主菜单: 史诗英雄感
        "key_root": note("D", 2),
        "tempo": 90,
        "progression": [("min", 0), ("maj", 8), ("maj", 3), ("min", 5)],
        "lead_wave": "saw",
        "pad_wave": "triangle",
        "lead_octave_offset": 12,
        "pad_octave_offset": 0,
        "lp_cutoff": 2400,
        "reverb_decay": 0.5,
        "duration": 60,
    },
}


# --------------------------- 单首 BGM 合成 ---------------------------

def synth_region_bgm(preset):
    tempo = preset["tempo"]
    bar_sec = 60.0 / tempo * 4  # 4/4 一小节
    duration = preset["duration"]
    n_bars = max(8, int(duration / bar_sec))
    progression = preset["progression"]

    pad_track = []
    lead_track = []
    bass_track = []

    rng = np.random.default_rng(seed=hash(preset["key_root"]) % (2**32))

    for bar_i in range(n_bars):
        kind, semitone_off = progression[bar_i % len(progression)]
        root = preset["key_root"] * (2 ** (semitone_off / 12.0))
        # Pad: 2 小节一换, 整段一个长和弦
        pad_freqs = chord_freqs(root * (2 ** (preset["pad_octave_offset"] / 12.0)), kind)
        pad_env = adsr(int(bar_sec * SR), attack=0.3, decay=0.2, sustain=0.85, release=0.5)
        pad = chord(pad_freqs, bar_sec, preset["pad_wave"], amp=0.18, env=pad_env)
        pad_track.append(pad)

        # Bass: 根音 + 五度交替, 每拍一次
        bass_seg = np.zeros(int(bar_sec * SR))
        for beat in range(4):
            f = root if beat % 2 == 0 else root * (2 ** (7 / 12.0))
            note_dur = bar_sec / 4 * 0.9
            note_env = adsr(int(note_dur * SR), attack=0.005, decay=0.15, sustain=0.4, release=0.3)
            t = tone(f, note_dur, "triangle", amp=0.32, env=note_env)
            start = int(beat * bar_sec / 4 * SR)
            end = min(start + len(t), len(bass_seg))
            bass_seg[start:end] += t[: end - start]
        bass_track.append(bass_seg)

        # Lead: 简单旋律 (从和弦音中随机抽 8 个 1/8 音符)
        lead_seg = np.zeros(int(bar_sec * SR))
        lead_freqs = chord_freqs(root * (2 ** (preset["lead_octave_offset"] / 12.0)), kind)
        for step in range(8):
            f = lead_freqs[rng.integers(0, len(lead_freqs))]
            # 偶尔加八度变化
            if rng.random() < 0.2:
                f *= 2
            note_dur = bar_sec / 8 * 0.85
            note_env = adsr(int(note_dur * SR), attack=0.01, decay=0.2, sustain=0.4, release=0.3)
            t = tone(f, note_dur, preset["lead_wave"], amp=0.18, env=note_env)
            start = int(step * bar_sec / 8 * SR)
            end = min(start + len(t), len(lead_seg))
            lead_seg[start:end] += t[: end - start]
        lead_track.append(lead_seg)

    pad_full = np.concatenate(pad_track)
    bass_full = np.concatenate(bass_track)
    lead_full = np.concatenate(lead_track)

    # 滤波 + 混音
    pad_full = lowpass(pad_full, preset["lp_cutoff"])
    lead_full = lowpass(lead_full, preset["lp_cutoff"] + 600)

    mixed = mix(pad_full, bass_full, lead_full, weights=[0.55, 0.45, 0.6])
    mixed = reverb(mixed, decay=preset["reverb_decay"], taps=10)
    mixed = loop_fade_seam(mixed, fade_sec=2.5)
    return mixed


# --------------------------- 写文件 + ffmpeg 转码 ---------------------------

def write_wav(path, audio_f, sr=SR):
    audio_i16 = np.clip(audio_f, -1.0, 1.0)
    audio_i16 = (audio_i16 * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(audio_i16.tobytes())


def ffmpeg_to_ogg(wav_path, ogg_path, quality=4):
    """ffmpeg 静音模式转 ogg vorbis"""
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", wav_path,
        "-c:a", "libvorbis",
        "-q:a", str(quality),
        ogg_path,
    ]
    res = subprocess.run(cmd, capture_output=True)
    if res.returncode != 0:
        sys.stderr.write(res.stderr.decode("utf-8", errors="ignore"))
        return False
    return True


# --------------------------- 缺失 SFX 合成 ---------------------------

def synth_missing_sfx():
    """合成 AudioManager 引用但 sfx 目录里实际缺失的几个音效"""
    needed = {
        # 这些已存在,跳过(检测靠 os.path.exists)
        "skill_learn.ogg": _synth_skill_learn,
        "skill_cast.ogg":  _synth_skill_cast,
        "boss_roar.ogg":   _synth_boss_roar,
        "boss_phase.ogg":  _synth_boss_phase,
        "purify.ogg":      _synth_purify,
        "buff_gain.ogg":   _synth_buff_gain,
        "freeze.ogg":      _synth_freeze_sfx,
        "summon.ogg":      _synth_summon_sfx,
        "chain.ogg":       _synth_chain_sfx,
        "fog_start.ogg":   _synth_fog_start,
        "interact.ogg":    _synth_interact,
        "ui_hover.ogg":    _synth_ui_hover,
        "error.ogg":       _synth_error,
    }
    os.makedirs(SFX_DIR, exist_ok=True)
    for filename, synth_fn in needed.items():
        target = os.path.join(SFX_DIR, filename)
        if os.path.exists(target):
            continue
        audio = synth_fn()
        wav_path = target.replace(".ogg", ".wav")
        write_wav(wav_path, audio)
        if ffmpeg_to_ogg(wav_path, target, quality=3):
            os.remove(wav_path)
            print(f"  [SFX] {filename}")
        else:
            print(f"  [SFX-FAIL] {filename}")


def _env(n, atk=0.01, dec=0.4, sus=0.0, rel=0.0):
    return adsr(n, atk, dec, sus, rel)


def _synth_skill_learn():
    n = int(0.7 * SR)
    env = _env(n, atk=0.01, dec=0.3, sus=0.4, rel=0.3)
    a = tone(note("C", 5), 0.7, "sine", 0.4, env)
    b = tone(note("E", 5), 0.7, "sine", 0.3, env)
    c = tone(note("G", 5), 0.7, "triangle", 0.25, env)
    return reverb(mix(a, b, c), decay=0.3, taps=4)


def _synth_skill_cast():
    n = int(0.4 * SR)
    env = _env(n, atk=0.005, dec=0.5, sus=0.0, rel=0.3)
    base = tone(note("A", 4), 0.4, "saw", 0.4, env)
    # 滑音
    t = np.arange(n) / SR
    sweep = np.sin(2 * np.pi * (300 + 800 * t / 0.4) * t) * env * 0.3
    return lowpass(mix(base, sweep), 3000)


def _synth_boss_roar():
    n = int(1.4 * SR)
    env = _env(n, atk=0.05, dec=0.4, sus=0.5, rel=0.4)
    t = np.arange(n) / SR
    # 低频咆哮 + FM 调制
    carrier = 90 + 20 * np.sin(2 * np.pi * 4 * t)
    x = np.sin(2 * np.pi * carrier * t) * env * 0.5
    noise = np.random.uniform(-1, 1, n) * env * 0.15
    return reverb(lowpass(x + noise, 800), decay=0.55, taps=8)


def _synth_boss_phase():
    n = int(1.0 * SR)
    env = _env(n, atk=0.005, dec=0.6, sus=0.2, rel=0.4)
    a = tone(note("E", 3), 1.0, "saw", 0.4, env)
    b = tone(note("B", 3), 1.0, "saw", 0.3, env)
    return reverb(lowpass(mix(a, b), 1500), decay=0.6, taps=6)


def _synth_purify():
    n = int(0.9 * SR)
    env = _env(n, atk=0.02, dec=0.5, sus=0.3, rel=0.3)
    out = np.zeros(n)
    for f in [note("C", 5), note("E", 5), note("G", 5), note("C", 6)]:
        out += tone(f, 0.9, "sine", 0.18, env)
    return reverb(out, decay=0.5, taps=6)


def _synth_buff_gain():
    n = int(0.5 * SR)
    env = _env(n, atk=0.005, dec=0.35, sus=0.3, rel=0.2)
    a = tone(note("D", 5), 0.5, "triangle", 0.35, env)
    b = tone(note("A", 5), 0.5, "sine", 0.25, env)
    return reverb(mix(a, b), decay=0.3, taps=4)


def _synth_freeze_sfx():
    n = int(0.8 * SR)
    env = _env(n, atk=0.02, dec=0.5, sus=0.2, rel=0.4)
    crystal = tone(note("E", 6), 0.8, "sine", 0.25, env)
    crystal2 = tone(note("B", 6), 0.8, "triangle", 0.15, env)
    noise = np.random.uniform(-1, 1, n) * env * 0.08
    return reverb(lowpass(mix(crystal, crystal2, noise), 6000), decay=0.5, taps=6)


def _synth_summon_sfx():
    n = int(0.7 * SR)
    env = _env(n, atk=0.05, dec=0.4, sus=0.3, rel=0.3)
    t = np.arange(n) / SR
    sweep = np.sin(2 * np.pi * (200 + 400 * t / 0.7) * t) * env * 0.4
    pad = tone(note("A", 3), 0.7, "saw", 0.25, env)
    return reverb(lowpass(mix(sweep, pad), 1500), decay=0.4, taps=6)


def _synth_chain_sfx():
    n = int(0.4 * SR)
    env = _env(n, atk=0.005, dec=0.5, sus=0.0, rel=0.2)
    t = np.arange(n) / SR
    crackle = np.sin(2 * np.pi * (1000 + 2000 * np.sin(2 * np.pi * 30 * t)) * t) * env * 0.3
    base = tone(note("E", 5), 0.4, "saw", 0.25, env)
    return reverb(lowpass(mix(crackle, base), 5000), decay=0.3, taps=4)


def _synth_fog_start():
    n = int(1.2 * SR)
    env = _env(n, atk=0.4, dec=0.4, sus=0.5, rel=0.4)
    noise = np.random.uniform(-1, 1, n) * env * 0.3
    pad = tone(note("F", 2), 1.2, "saw", 0.2, env)
    return reverb(lowpass(mix(noise, pad), 600), decay=0.6, taps=8)


def _synth_interact():
    n = int(0.25 * SR)
    env = _env(n, atk=0.005, dec=0.3, sus=0.0, rel=0.0)
    a = tone(note("E", 5), 0.25, "sine", 0.3, env)
    b = tone(note("G", 5), 0.25, "triangle", 0.2, env)
    return mix(a, b)


def _synth_ui_hover():
    n = int(0.12 * SR)
    env = _env(n, atk=0.005, dec=0.3, sus=0.0, rel=0.0)
    return tone(note("A", 5), 0.12, "sine", 0.2, env)


def _synth_error():
    n = int(0.3 * SR)
    env = _env(n, atk=0.005, dec=0.4, sus=0.0, rel=0.0)
    a = tone(note("D", 4), 0.3, "square", 0.25, env)
    b = tone(note("D#", 4), 0.3, "square", 0.2, env)
    return mix(a, b)


# --------------------------- 主入口 ---------------------------

def main():
    if shutil.which("ffmpeg") is None:
        print("[ERR] ffmpeg 未在 PATH 中, 无法转码 ogg")
        return 1
    os.makedirs(BGM_DIR, exist_ok=True)

    print("[BGM] 合成区域 BGM ...")
    for region, preset in REGION_PRESETS.items():
        target = os.path.join(BGM_DIR, f"bgm_{region}.ogg")
        if os.path.exists(target) and os.environ.get("BGM_FORCE", "0") != "1":
            print(f"  [SKIP] bgm_{region}.ogg 已存在(BGM_FORCE=1 强制覆盖)")
            continue
        print(f"  合成 {region} ({preset['duration']}s @ {preset['tempo']}bpm)...")
        audio = synth_region_bgm(preset)
        wav_path = target.replace(".ogg", ".wav")
        write_wav(wav_path, audio)
        if ffmpeg_to_ogg(wav_path, target, quality=4):
            os.remove(wav_path)
            print(f"  [OK] bgm_{region}.ogg")
        else:
            print(f"  [FAIL] bgm_{region}.ogg")

    print("[SFX] 补全缺失音效 ...")
    synth_missing_sfx()
    print("[BGM] 完成")
    return 0


if __name__ == "__main__":
    sys.exit(main())
