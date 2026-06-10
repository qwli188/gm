extends Node
## AudioManager - 游戏音效管理器（全局单例）
## 统一管理所有音效的播放，通过 play(name) 调用
## BGM 层: 通过 play_bgm(region_id) 切换地图音乐

const SFX_DIR = "res://assets/audio/sfx/"
const BGM_DIR = "res://assets/audio/bgm/"

# 音效映射表：语义名称 → 文件
const SFX_MAP = {
	"attack":      "attack.ogg",
	"hit":         "hit.ogg",
	"hit_crit":    "hit.ogg",
	"coin":        "coin.ogg",
	"item_drop":   "item_drop.ogg",
	"equip":       "equip.ogg",
	"level_up":    "level_up.ogg",
	"ui_click":    "ui_click.ogg",
	"footstep":    "footstep00.ogg",
	# B1新增映射(若文件缺失会用回退音效)
	"skill_learn": "level_up.ogg",   # 学习技能 → 复用升级音
	"skill_cast":  "attack.ogg",
	"error":       "ui_click.ogg",
	"ui_hover":    "ui_click.ogg",
	"fog_start":   "hit.ogg",        # 死亡之雾起 → 复用击中
	"boss_roar":   "hit.ogg",
	"boss_phase":  "level_up.ogg",   # Boss阶段转换
	"interact":    "coin.ogg",
	"purify":      "level_up.ogg",
	"buff_gain":   "equip.ogg",
	"freeze":      "hit.ogg",
	"summon":      "equip.ogg",
	"chain":       "attack.ogg",
}

# BGM 映射: region → bgm 文件 (由 build_all.py 程序化合成)
const BGM_MAP = {
	"crypt":  "bgm_crypt.ogg",
	"swamp":  "bgm_swamp.ogg",
	"forge":  "bgm_forge.ogg",
	"ice":    "bgm_ice.ogg",
	"void":   "bgm_void.ogg",
	"field":  "bgm_field.ogg",
	"town":   "bgm_town.ogg",
	"menu":   "bgm_menu.ogg",
}

# 预加载音频池（每种 3 个播放器，避免同帧重叠音被截断）
var _pools: Dictionary = {}
# BGM 播放器(单实例,带 fade)
var _bgm_player: AudioStreamPlayer = null
var _bgm_current: String = ""

func _ready():
	print("[AudioManager] 音效系统初始化")
	for key in SFX_MAP:
		var path = SFX_DIR + SFX_MAP[key]
		var stream = load(path) as AudioStream
		if stream == null:
			# 尝试回退到通用音效以避免噪声告警
			stream = load(SFX_DIR + "ui_click.ogg") as AudioStream
			if stream == null:
				push_warning("[AudioManager] 找不到音效: %s" % path)
				continue
		var pool = []
		for i in range(3):
			var player = AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = -6.0
			add_child(player)
			pool.append(player)
		_pools[key] = pool
	# 初始化 BGM 播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -10.0
	add_child(_bgm_player)

## 播放音效。name 对应 SFX_MAP 的键
func play(name: String, volume_db: float = 0.0):
	if not _pools.has(name):
		return
	var pool = _pools[name]
	# 找到一个没在播放的播放器
	for player in pool:
		if not player.playing:
			player.volume_db = -6.0 + volume_db
			player.play()
			return
	# 全在播放就抢第一个
	pool[0].play()

## 切换 BGM(按 region_id) — 同名忽略,跨曲淡入
func play_bgm(region_id: String):
	if region_id == _bgm_current:
		return
	if not BGM_MAP.has(region_id):
		return
	var path = BGM_DIR + BGM_MAP[region_id]
	var stream = load(path) as AudioStream
	if stream == null:
		# BGM 文件还没生成,静默跳过
		return
	if _bgm_player == null:
		return
	# 0.6s 淡出 → 切换 → 淡入
	if _bgm_player.playing:
		var tw = create_tween()
		tw.tween_property(_bgm_player, "volume_db", -40.0, 0.4)
		tw.tween_callback(func():
			_bgm_player.stream = stream
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			_bgm_player.play()
		)
		tw.tween_property(_bgm_player, "volume_db", -10.0, 0.6)
	else:
		_bgm_player.stream = stream
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_bgm_player.volume_db = -10.0
		_bgm_player.play()
	_bgm_current = region_id

func stop_bgm():
	if _bgm_player and _bgm_player.playing:
		var tw = create_tween()
		tw.tween_property(_bgm_player, "volume_db", -40.0, 0.5)
		tw.tween_callback(func(): _bgm_player.stop())
	_bgm_current = ""
