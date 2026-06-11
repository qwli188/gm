# -*- coding: utf-8 -*-
"""
Kenney素材自动下载与集成
- Tiny Dungeon: 角色/敌人/地牢tiles
- 自动下载 → 分类 → 转换Godot格式
- 输出: project/src/assets/kenney/
"""
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).parent.parent
KENNEY_DIR = ROOT / "project" / "src" / "assets" / "kenney"
KENNEY_DIR.mkdir(parents=True, exist_ok=True)

# Kenney免费素材包(CC0许可)
# 注：kenney.nl 网站结构变更后，部分直链 URL 可能失效。
# 新增素材推荐手动从 kenney.nl 或 kenney.itch.io 下载，放入 assets/kenney/ 子目录。
# 已确认可用的早期 URL 保留如下：
KENNEY_PACKS = [
    {
        "name": "tiny_dungeon",
        "url": "https://kenney.nl/content/3-assets/50-tiny-dungeon/tiny-dungeon.zip",
        "desc": "完整地牢素材(角色/敌人/tiles/道具)"
    },
    {
        "name": "micro_roguelike",
        "url": "https://kenney.nl/content/3-assets/79-micro-roguelike/micro-roguelike.zip",
        "desc": "Roguelike角色/怪物"
    },
    # 待集成素材（URL 失效后需手动放入对应目录）：
    # - rpg_urban_pack: 城镇场景(建筑/NPC)
    # - platformer_pack_redux: 通用角色动画
    # - particle_pack: 粒子特效
    # 推荐方式：从 https://kenney.itch.io/kenney-game-assets 下载 All-in-1 整包
]

def download_pack(pack):
    """下载并解压Kenney素材包"""
    print(f"  [下载] {pack['name']}...")

    out_dir = KENNEY_DIR / pack['name']
    if out_dir.exists():
        print(f"    已存在,跳过")
        return True

    zip_path = KENNEY_DIR / f"{pack['name']}.zip"

    try:
        # 下载
        urllib.request.urlretrieve(pack['url'], zip_path)

        # 解压
        with zipfile.ZipFile(zip_path, 'r') as z:
            z.extractall(out_dir)

        # 清理zip
        zip_path.unlink()

        print(f"    [OK] {pack['desc']}")
        return True

    except Exception as e:
        print(f"    [FAIL] {e}")
        return False

def organize_sprites():
    """整理精灵到Godot项目结构"""
    print("\n  [整理] 精灵分类...")

    # tiny_dungeon结构: Tiles/, Enemies/, Characters/, Items/
    td = KENNEY_DIR / "tiny_dungeon"
    if not td.exists():
        return

    # 统计
    counts = {}
    for subdir in ["Tiles", "Enemies", "Characters", "Items"]:
        src = td / subdir
        if src.exists():
            counts[subdir] = len(list(src.glob("*.png")))

    for k, v in counts.items():
        print(f"    {k}: {v} 张")

def create_import_script():
    """生成Godot导入辅助脚本"""
    script = """# KenneyImporter.gd - Kenney素材自动导入工具
# 用法: 在Godot脚本编辑器运行,自动生成SpriteFrames

extends Node

func import_tiny_dungeon():
    var base = "res://assets/kenney/tiny_dungeon/"

    # 角色精灵
    var char_frames = SpriteFrames.new()
    char_frames.add_animation("idle")
    # 遍历 Characters/*.png 添加帧
    var dir = DirAccess.open(base + "Characters/")
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        while file != "":
            if file.ends_with(".png"):
                var tex = load(base + "Characters/" + file)
                char_frames.add_frame("idle", tex)
            file = dir.get_next()

    # 保存为资源
    ResourceSaver.save(char_frames, "res://assets/kenney_characters.tres")
    print("[Kenney] 角色SpriteFrames已保存")

func import_tiles():
    # TODO: 生成TileSet
    pass
"""

    path = ROOT / "project" / "src" / "autoload" / "KenneyImporter.gd"
    with open(path, "w", encoding="utf-8") as f:
        f.write(script)

    print("\n  [生成] KenneyImporter.gd")

def main():
    print("=" * 60)
    print("  Kenney素材自动下载与集成")
    print("=" * 60)

    success = 0
    for pack in KENNEY_PACKS:
        if download_pack(pack):
            success += 1

    if success > 0:
        organize_sprites()
        create_import_script()

    print("\n=" * 60)
    print(f"  [完成] {success}/{len(KENNEY_PACKS)} 素材包")
    print("  [位置] project/src/assets/kenney/")
    print("=" * 60)

if __name__ == "__main__":
    main()
