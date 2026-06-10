# -*- coding: utf-8 -*-
"""
程序化地牢布局生成器
- BSP分割生成房间
- 随机走廊连接
- 障碍物/装饰物自动散布
输出: project/src/assets/generated/dungeon_layouts/*.json
"""
import os
import json
import random
from pathlib import Path

ROOT = Path(__file__).parent.parent
OUT = ROOT / "project" / "src" / "assets" / "generated" / "dungeon_layouts"
OUT.mkdir(parents=True, exist_ok=True)

REGIONS = ["crypt", "swamp", "forge", "ice", "void", "field", "chaos"]
TILE_SIZE = 64

class Room:
    def __init__(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h
        self.center = (x + w // 2, y + h // 2)

def bsp_split(x, y, w, h, depth=0, max_depth=3):
    """BSP递归分割生成房间"""
    if depth >= max_depth or w < 8 or h < 8:
        # 生成叶子房间(留边距)
        room_w = min(w - 1, max(4, random.randint(w - 3, w - 1)))
        room_h = min(h - 1, max(4, random.randint(h - 3, h - 1)))
        room_x = x + random.randint(0, max(0, w - room_w - 1))
        room_y = y + random.randint(0, max(0, h - room_h - 1))
        return [Room(room_x, room_y, room_w, room_h)]

    # 随机横切或竖切
    if random.random() < 0.5 and w > 10:
        # 竖切
        split_x = random.randint(x + 5, x + w - 5)
        left = bsp_split(x, y, split_x - x, h, depth + 1, max_depth)
        right = bsp_split(split_x, y, x + w - split_x, h, depth + 1, max_depth)
        return left + right
    elif h > 10:
        # 横切
        split_y = random.randint(y + 5, y + h - 5)
        top = bsp_split(x, y, w, split_y - y, depth + 1, max_depth)
        bottom = bsp_split(x, split_y, w, y + h - split_y, depth + 1, max_depth)
        return top + bottom
    else:
        return [Room(x + 1, y + 1, max(4, w - 2), max(4, h - 2))]

def connect_rooms(rooms):
    """生成房间间走廊"""
    corridors = []
    for i in range(len(rooms) - 1):
        r1, r2 = rooms[i], rooms[i + 1]
        cx1, cy1 = r1.center
        cx2, cy2 = r2.center
        # L形走廊
        if random.random() < 0.5:
            corridors.append({"type": "h", "x1": min(cx1, cx2), "x2": max(cx1, cx2), "y": cy1})
            corridors.append({"type": "v", "x": cx2, "y1": min(cy1, cy2), "y2": max(cy1, cy2)})
        else:
            corridors.append({"type": "v", "x": cx1, "y1": min(cy1, cy2), "y2": max(cy1, cy2)})
            corridors.append({"type": "h", "x1": min(cx1, cx2), "x2": max(cx1, cx2), "y": cy2})
    return corridors

def place_obstacles(rooms, density=0.15):
    """随机放置障碍物"""
    obstacles = []
    for room in rooms:
        count = int(room.w * room.h * density)
        for _ in range(count):
            ox = random.randint(room.x + 1, room.x + room.w - 2)
            oy = random.randint(room.y + 1, room.y + room.h - 2)
            obstacles.append({"x": ox, "y": oy, "type": "rock"})
    return obstacles

def generate_dungeon(region, dungeon_id, width=50, height=40):
    """生成单个副本布局"""
    random.seed(hash(dungeon_id) % 10000)

    rooms = bsp_split(0, 0, width, height, max_depth=3)
    corridors = connect_rooms(rooms)
    obstacles = place_obstacles(rooms, density=0.12)

    # Boss房间(最后一个房间)
    boss_room = rooms[-1]

    # 玩家出生点(第一个房间中心)
    spawn = {"x": rooms[0].center[0], "y": rooms[0].center[1]}

    return {
        "id": dungeon_id,
        "region": region,
        "width": width,
        "height": height,
        "tile_size": TILE_SIZE,
        "spawn_point": spawn,
        "rooms": [{"x": r.x, "y": r.y, "w": r.w, "h": r.h} for r in rooms],
        "corridors": corridors,
        "obstacles": obstacles,
        "boss_arena": {"x": boss_room.x, "y": boss_room.y, "w": boss_room.w, "h": boss_room.h}
    }

def main():
    print("=" * 60)
    print("  程序化地牢布局生成")
    print("=" * 60)

    count = 0
    for region in REGIONS:
        for i in range(1, 4):  # 每区域3个副本
            dungeon_id = f"dungeon_{region}_{i}"
            layout = generate_dungeon(region, dungeon_id)

            path = OUT / f"{dungeon_id}.json"
            with open(path, "w", encoding="utf-8") as f:
                json.dump(layout, f, indent=2, ensure_ascii=False)
            count += 1

    print(f"  [完成] 生成 {count} 个副本布局")
    print("=" * 60)

if __name__ == "__main__":
    main()
