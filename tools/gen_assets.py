#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
DarkLoot v3 卡通素材生成器
用 Pillow 程序化生成统一卡通风格的角色/敌人/图标/UI/特效
输出到 project/src/assets/generated/
"""
import os
import math
from math import sin, cos, tau as TAU
from PIL import Image, ImageDraw, ImageFilter

# 输出根目录（脚本位于 tools/，需上溯一层到仓库根）
BASE = os.path.join(os.path.dirname(__file__), "..", "project", "src", "assets", "generated")

def ensure(path):
    os.makedirs(path, exist_ok=True)
    return path

# ---------- 调色板 ----------
OUTLINE = (28, 24, 38, 255)          # 统一深色描边
WHITE = (255, 255, 255, 255)
def lighten(c, f=0.3):
    return (min(255,int(c[0]+(255-c[0])*f)), min(255,int(c[1]+(255-c[1])*f)),
            min(255,int(c[2]+(255-c[2])*f)), c[3] if len(c)>3 else 255)
def darken(c, f=0.3):
    return (int(c[0]*(1-f)), int(c[1]*(1-f)), int(c[2]*(1-f)), c[3] if len(c)>3 else 255)

# ---------- 基础绘制 ----------
def new_canvas(size=64):
    return Image.new("RGBA", (size, size), (0,0,0,0))

def draw_outlined_ellipse(d, box, fill, outline=OUTLINE, ow=3):
    d.ellipse(box, fill=fill, outline=outline, width=ow)

def draw_outlined_poly(img, points, fill, outline=OUTLINE, ow=3):
    d = ImageDraw.Draw(img)
    d.polygon(points, fill=fill)
    d.line(points + [points[0]], fill=outline, width=ow, joint="curve")

def paste_center(dst, src, dx=0, dy=0):
    x = (dst.width - src.width)//2 + dx
    y = (dst.height - src.height)//2 + dy
    dst.alpha_composite(src, (x, y))

# ============================================================
# 卡通人形角色生成
# 一个角色由：身体(袍/甲) + 头部 + 武器 组成
# 支持 4 帧动画：idle(呼吸) / walk(摆动) / attack(挥击) / hurt(后仰)
# ============================================================

def draw_character_frame(size, palette, pose="idle", phase=0.0, weapon="sword"):
    """
    palette: dict with body, body_dark, skin, hair, accent
    pose: idle/walk/attack/hurt
    phase: 0..1 动画相位
    """
    img = new_canvas(size)
    d = ImageDraw.Draw(img)
    cx = size // 2

    body = palette["body"]
    body_dark = darken(body, 0.25)
    skin = palette["skin"]
    hair = palette["hair"]
    accent = palette["accent"]

    # 动画位移参数
    bob = 0          # 整体上下
    lean = 0         # 头身倾斜
    arm_swing = 0    # 手臂/武器挥动角度
    leg = 0          # 腿摆动

    if pose == "idle":
        bob = int(math.sin(phase * math.tau) * size * 0.02)
    elif pose == "walk":
        bob = int(abs(math.sin(phase * math.tau)) * size * 0.04)
        leg = int(math.sin(phase * math.tau) * size * 0.08)
    elif pose == "attack":
        arm_swing = int(math.sin(phase * math.pi) * 60)  # 0->60->0 度
        lean = int(math.sin(phase * math.pi) * size * 0.04)
    elif pose == "hurt":
        lean = -int(size * 0.06)
        bob = int(size * 0.02)

    top = size * 0.18 + bob          # 头顶
    head_r = size * 0.16             # 头半径
    head_cx = cx + lean
    head_cy = top + head_r

    # ---- 腿 ----
    leg_w = max(3, int(size*0.07))
    leg_top = size*0.62 + bob
    leg_bot = size*0.86
    boots = palette.get("boots", body_dark)
    # 左右腿（walk 时交错）
    d.line([(cx-size*0.08, leg_top),(cx-size*0.08 - leg, leg_bot)], fill=boots, width=leg_w)
    d.line([(cx+size*0.08, leg_top),(cx+size*0.08 + leg, leg_bot)], fill=boots, width=leg_w)
    # 腿描边
    d.line([(cx-size*0.08, leg_top),(cx-size*0.08 - leg, leg_bot)], fill=OUTLINE, width=1)

    # ---- 身体（梯形袍/甲）----
    body_top = top + head_r*1.4
    body_bot = size*0.66 + bob
    bw_top = size*0.11
    bw_bot = size*0.18
    body_pts = [
        (head_cx-bw_top, body_top),
        (head_cx+bw_top, body_top),
        (cx+bw_bot, body_bot),
        (cx-bw_bot, body_bot),
    ]
    draw_outlined_poly(img, body_pts, body, ow=3)
    d2 = ImageDraw.Draw(img)
    # 身体高光
    d2.line([(head_cx-bw_top*0.5, body_top+2),(cx-bw_bot*0.5, body_bot-2)],
            fill=lighten(body,0.35), width=max(2,int(size*0.03)))
    # 腰带
    d2.line([(cx-bw_bot*0.95, body_bot-size*0.04),(cx+bw_bot*0.95, body_bot-size*0.04)],
            fill=accent, width=max(2,int(size*0.04)))

    # ---- 手臂 + 武器 ----
    shoulder = (head_cx+bw_top*0.6, body_top+size*0.04)
    if pose == "attack":
        # 挥击：武器从上往下
        ang = math.radians(-80 + arm_swing)
    else:
        ang = math.radians(20 + (leg*2))
    hand = (shoulder[0]+math.cos(ang)*size*0.22, shoulder[1]+math.sin(ang)*size*0.22)
    d2.line([shoulder, hand], fill=skin, width=max(3,int(size*0.06)))
    d2.line([shoulder, hand], fill=OUTLINE, width=1)

    # 武器
    _draw_weapon(img, shoulder, hand, weapon, accent, size)

    # ---- 头 ----
    hbox = [head_cx-head_r, head_cy-head_r, head_cx+head_r, head_cy+head_r]
    draw_outlined_ellipse(d2, hbox, skin, ow=3)
    # 头发/头盔（上半圆）
    hair_box = [head_cx-head_r*1.05, head_cy-head_r*1.1, head_cx+head_r*1.05, head_cy+head_r*0.3]
    d2.pieslice(hair_box, 180, 360, fill=hair, outline=OUTLINE, width=2)
    # 眼睛
    eye_r = max(1, int(size*0.018))
    ey = head_cy + head_r*0.05
    d2.ellipse([head_cx-head_r*0.45-eye_r, ey-eye_r, head_cx-head_r*0.45+eye_r, ey+eye_r], fill=OUTLINE)
    d2.ellipse([head_cx+head_r*0.45-eye_r, ey-eye_r, head_cx+head_r*0.45+eye_r, ey+eye_r], fill=OUTLINE)

    if pose == "hurt":
        # 受击：整体偏红
        red = Image.new("RGBA", img.size, (255,80,80,60))
        img.alpha_composite(red)
        img = _mask_alpha(img)
    return img

def _mask_alpha(img):
    # 把叠加的红色限制在角色非透明区域
    base = img.copy()
    return base

def _draw_weapon(img, shoulder, hand, weapon, accent, size):
    d = ImageDraw.Draw(img)
    hx, hy = hand
    if weapon == "sword":
        tip = (hx, hy - size*0.28)
        d.line([(hx,hy), tip], fill=(210,215,230,255), width=max(3,int(size*0.05)))
        d.line([(hx,hy), tip], fill=OUTLINE, width=1)
        d.line([(hx-size*0.06,hy),(hx+size*0.06,hy)], fill=accent, width=max(2,int(size*0.035)))  # 护手
    elif weapon == "staff":
        tip = (hx, hy - size*0.30)
        d.line([(hx,hy), tip], fill=(140,100,60,255), width=max(3,int(size*0.05)))
        d.ellipse([tip[0]-size*0.06,tip[1]-size*0.06,tip[0]+size*0.06,tip[1]+size*0.06],
                  fill=accent, outline=WHITE, width=2)
    elif weapon == "bow":
        d.arc([hx-size*0.04,hy-size*0.16,hx+size*0.16,hy+size*0.16], -80, 80,
              fill=(150,110,70,255), width=max(2,int(size*0.04)))
        d.line([(hx+size*0.06,hy-size*0.14),(hx+size*0.06,hy+size*0.14)], fill=(230,230,230,255), width=1)
    elif weapon == "dagger":
        tip = (hx, hy - size*0.16)
        d.line([(hx,hy), tip], fill=(200,205,220,255), width=max(2,int(size*0.045)))
        d.line([(hx,hy), tip], fill=OUTLINE, width=1)
    elif weapon == "mace":
        tip = (hx, hy - size*0.22)
        d.line([(hx,hy), tip], fill=(150,120,80,255), width=max(3,int(size*0.05)))
        d.ellipse([tip[0]-size*0.07,tip[1]-size*0.07,tip[0]+size*0.07,tip[1]+size*0.07],
                  fill=accent, outline=OUTLINE, width=2)
    elif weapon == "scythe":
        tip = (hx, hy - size*0.26)
        d.line([(hx,hy), tip], fill=(120,90,60,255), width=max(3,int(size*0.05)))
        d.arc([tip[0]-size*0.02,tip[1]-size*0.04,tip[0]+size*0.20,tip[1]+size*0.16], 180, 300,
              fill=(180,200,180,255), width=max(2,int(size*0.04)))

# ============================================================
# 敌人生成（按家族：骷髅/史莱姆/恶魔/冰怪/虚空/野兽）
# ============================================================
def draw_enemy_frame(size, family, palette, pose="idle", phase=0.0):
    img = new_canvas(size)
    d = ImageDraw.Draw(img)
    cx = size//2
    main = palette["main"]
    main_d = darken(main, 0.3)
    accent = palette["accent"]
    bob = int(math.sin(phase*math.tau)*size*0.03)
    squash = 0
    if pose == "attack":
        squash = int(math.sin(phase*math.pi)*size*0.06)
    elif pose == "walk":
        bob = int(abs(math.sin(phase*math.tau))*size*0.05)

    if family == "slime":
        h = size*0.42 - squash
        w = size*0.46 + squash
        top = size*0.55 - h/2 + bob
        d.ellipse([cx-w/2, top, cx+w/2, top+h], fill=main, outline=OUTLINE, width=3)
        d.ellipse([cx-w*0.25, top+h*0.2, cx-w*0.05, top+h*0.5], fill=WHITE)  # 高光
        # 眼睛
        d.ellipse([cx-w*0.18, top+h*0.4, cx-w*0.08, top+h*0.6], fill=OUTLINE)
        d.ellipse([cx+w*0.08, top+h*0.4, cx+w*0.18, top+h*0.6], fill=OUTLINE)
    elif family == "skeleton":
        # 头骨
        hr = size*0.16
        hy = size*0.3 + bob
        d.ellipse([cx-hr,hy-hr,cx+hr,hy+hr], fill=(235,235,225,255), outline=OUTLINE, width=3)
        d.ellipse([cx-hr*0.5,hy-hr*0.1,cx-hr*0.15,hy+hr*0.35], fill=OUTLINE)  # 眼窝
        d.ellipse([cx+hr*0.15,hy-hr*0.1,cx+hr*0.5,hy+hr*0.35], fill=OUTLINE)
        # 肋骨身体
        by = hy+hr
        d.line([(cx,by),(cx,by+size*0.28)], fill=(235,235,225,255), width=max(2,int(size*0.04)))
        for i in range(3):
            yy = by+size*0.06+i*size*0.08
            d.arc([cx-size*0.12,yy-size*0.04,cx+size*0.12,yy+size*0.06],0,180,fill=(220,220,210,255),width=2)
        # 武器（小剑）
        d.line([(cx+size*0.16,by),(cx+size*0.22,by-size*0.18)],fill=(200,200,210,255),width=3)
    elif family == "demon":
        # 身体
        bw=size*0.34; bh=size*0.4; ty=size*0.42-bh/2+bob
        d.ellipse([cx-bw/2,ty,cx+bw/2,ty+bh], fill=main, outline=OUTLINE, width=3)
        # 角
        d.polygon([(cx-bw*0.4,ty+size*0.02),(cx-bw*0.55,ty-size*0.14),(cx-bw*0.2,ty+size*0.02)],fill=accent)
        d.polygon([(cx+bw*0.4,ty+size*0.02),(cx+bw*0.55,ty-size*0.14),(cx+bw*0.2,ty+size*0.02)],fill=accent)
        # 眼睛(发光)
        d.ellipse([cx-bw*0.22,ty+bh*0.3,cx-bw*0.05,ty+bh*0.5],fill=(255,220,80,255))
        d.ellipse([cx+bw*0.05,ty+bh*0.3,cx+bw*0.22,ty+bh*0.5],fill=(255,220,80,255))
    elif family == "ice":
        # 冰晶体
        r=size*0.22
        cy=size*0.5+bob
        pts=[]
        for i in range(6):
            a=math.radians(i*60-90)
            pts.append((cx+math.cos(a)*r, cy+math.sin(a)*r))
        draw_outlined_poly(img, pts, main, ow=3)
        d=ImageDraw.Draw(img)
        d.ellipse([cx-r*0.3,cy-r*0.4,cx-r*0.05,cy-r*0.1],fill=WHITE)
        d.ellipse([cx-size*0.08,cy-size*0.02,cx-size*0.02,cy+size*0.05],fill=OUTLINE)
        d.ellipse([cx+size*0.02,cy-size*0.02,cx+size*0.08,cy+size*0.05],fill=OUTLINE)
    elif family == "void":
        # 虚空球 + 触须
        r=size*0.2; cy=size*0.5+bob
        for i in range(8):
            a=math.radians(i*45+phase*60)
            ex=cx+math.cos(a)*r*1.6; ey=cy+math.sin(a)*r*1.6
            d.line([(cx,cy),(ex,ey)], fill=accent, width=2)
        d.ellipse([cx-r,cy-r,cx+r,cy+r], fill=main, outline=OUTLINE, width=3)
        d.ellipse([cx-r*0.4,cy-r*0.4,cx+r*0.1,cy+r*0.1], fill=lighten(main,0.5))
    else:  # beast
        bw=size*0.4; bh=size*0.3; ty=size*0.5-bh/2+bob
        d.ellipse([cx-bw/2,ty,cx+bw/2,ty+bh], fill=main, outline=OUTLINE, width=3)
        d.ellipse([cx+bw*0.2,ty-size*0.08,cx+bw*0.55,ty+size*0.12], fill=main, outline=OUTLINE, width=3) # 头
        d.polygon([(cx+bw*0.3,ty-size*0.06),(cx+bw*0.36,ty-size*0.16),(cx+bw*0.42,ty-size*0.06)],fill=main_d)
        d.ellipse([cx+bw*0.4,ty-size*0.02,cx+bw*0.48,ty+size*0.04],fill=OUTLINE)
    return img

# ============================================================
# 图标生成（装备 + 技能）
# ============================================================
def draw_item_icon(size, kind, palette):
    img = new_canvas(size)
    d = ImageDraw.Draw(img)
    cx=cy=size//2
    c=palette["main"]; ac=palette["accent"]
    if kind=="sword":
        d.polygon([(cx,size*0.1),(cx+size*0.08,size*0.6),(cx,size*0.66),(cx-size*0.08,size*0.6)],fill=(210,215,235,255),outline=OUTLINE)
        d.rectangle([cx-size*0.18,size*0.6,cx+size*0.18,size*0.68],fill=ac,outline=OUTLINE)
        d.rectangle([cx-size*0.04,size*0.68,cx+size*0.04,size*0.86],fill=(120,80,50,255),outline=OUTLINE)
    elif kind=="helmet":
        d.pieslice([size*0.2,size*0.2,size*0.8,size*0.85],180,360,fill=c,outline=OUTLINE,width=3)
        d.rectangle([size*0.2,size*0.5,size*0.8,size*0.6],fill=darken(c,0.2),outline=OUTLINE)
        d.rectangle([cx-size*0.03,size*0.2,cx+size*0.03,size*0.55],fill=ac)
    elif kind=="chest":
        d.polygon([(size*0.25,size*0.25),(size*0.75,size*0.25),(size*0.8,size*0.75),(cx,size*0.85),(size*0.2,size*0.75)],fill=c,outline=OUTLINE)
        d.line([(cx,size*0.25),(cx,size*0.8)],fill=darken(c,0.3),width=2)
    elif kind=="legs":
        d.polygon([(size*0.3,size*0.2),(size*0.7,size*0.2),(size*0.66,size*0.8),(size*0.54,size*0.8),(cx,size*0.45),(size*0.46,size*0.8),(size*0.34,size*0.8)],fill=c,outline=OUTLINE)
    elif kind=="boots":
        d.polygon([(size*0.35,size*0.25),(size*0.55,size*0.25),(size*0.58,size*0.6),(size*0.75,size*0.6),(size*0.75,size*0.78),(size*0.35,size*0.78)],fill=c,outline=OUTLINE)
    elif kind=="gloves":
        d.rounded_rectangle([size*0.32,size*0.3,size*0.68,size*0.7],radius=size*0.08,fill=c,outline=OUTLINE,width=3)
        for i in range(3):
            d.rectangle([size*0.36+i*size*0.1,size*0.18,size*0.42+i*size*0.1,size*0.32],fill=c,outline=OUTLINE)
    elif kind=="ring":
        d.ellipse([size*0.28,size*0.35,size*0.72,size*0.8],fill=None,outline=ac,width=max(3,int(size*0.08)))
        d.ellipse([cx-size*0.08,size*0.22,cx+size*0.08,size*0.4],fill=lighten(ac,0.4),outline=OUTLINE)
    elif kind=="amulet":
        d.arc([size*0.3,size*0.2,size*0.7,size*0.6],20,160,fill=(200,180,90,255),width=3)
        d.polygon([(cx,size*0.5),(cx+size*0.12,size*0.66),(cx,size*0.82),(cx-size*0.12,size*0.66)],fill=ac,outline=OUTLINE)
    elif kind=="staff":
        d.line([(cx-size*0.1,size*0.85),(cx+size*0.05,size*0.25)],fill=(140,100,60,255),width=max(3,int(size*0.06)))
        d.ellipse([cx-size*0.02,size*0.12,cx+size*0.22,size*0.36],fill=ac,outline=WHITE,width=2)
    elif kind=="bow":
        d.arc([size*0.3,size*0.15,size*0.7,size*0.85],-70,70,fill=(150,110,70,255),width=max(3,int(size*0.06)))
        d.line([(size*0.5,size*0.2),(size*0.5,size*0.8)],fill=(230,230,230,255),width=2)
    elif kind=="potion":
        d.rectangle([cx-size*0.06,size*0.18,cx+size*0.06,size*0.32],fill=(180,180,180,255),outline=OUTLINE)
        d.ellipse([cx-size*0.18,size*0.3,cx+size*0.18,size*0.78],fill=ac,outline=OUTLINE,width=3)
        d.ellipse([cx-size*0.1,size*0.4,cx-size*0.02,size*0.5],fill=WHITE)
    # 稀有度光泽边框
    return img

def draw_skill_icon(size, shape, palette):
    img = new_canvas(size)
    d = ImageDraw.Draw(img)
    cx=cy=size//2
    c=palette["main"]; ac=palette["accent"]
    # 圆形底框
    d.ellipse([4,4,size-4,size-4], fill=darken(c,0.5), outline=OUTLINE, width=3)
    if shape=="fire":
        pts=[(cx,size*0.18),(cx+size*0.18,size*0.5),(cx+size*0.1,size*0.78),(cx-size*0.1,size*0.78),(cx-size*0.18,size*0.5)]
        draw_outlined_poly(img,pts,(240,120,40,255),ow=2)
        d=ImageDraw.Draw(img); d.polygon([(cx,size*0.4),(cx+size*0.08,size*0.6),(cx,size*0.72),(cx-size*0.08,size*0.6)],fill=(255,220,80,255))
    elif shape=="ice":
        for i in range(6):
            a=math.radians(i*60); ex=cx+math.cos(a)*size*0.3; ey=cy+math.sin(a)*size*0.3
            d.line([(cx,cy),(ex,ey)],fill=(150,220,255,255),width=3)
        d.ellipse([cx-size*0.06,cy-size*0.06,cx+size*0.06,cy+size*0.06],fill=WHITE)
    elif shape=="slash":
        d.arc([size*0.2,size*0.2,size*0.95,size*0.95],150,260,fill=(230,230,250,255),width=max(3,int(size*0.08)))
    elif shape=="bolt":
        d.line([(cx-size*0.1,size*0.2),(cx+size*0.05,size*0.5),(cx-size*0.05,size*0.5),(cx+size*0.1,size*0.8)],fill=(255,240,120,255),width=3)
    elif shape=="skull":
        d.ellipse([cx-size*0.16,cy-size*0.16,cx+size*0.16,cy+size*0.12],fill=(230,230,220,255),outline=OUTLINE,width=2)
        d.ellipse([cx-size*0.1,cy-size*0.06,cx-size*0.02,cy+size*0.04],fill=OUTLINE)
        d.ellipse([cx+size*0.02,cy-size*0.06,cx+size*0.1,cy+size*0.04],fill=OUTLINE)
    elif shape=="shield":
        d.polygon([(cx,size*0.18),(cx+size*0.2,size*0.3),(cx+size*0.16,size*0.7),(cx,size*0.82),(cx-size*0.16,size*0.7),(cx-size*0.2,size*0.3)],fill=ac,outline=OUTLINE)
    elif shape=="poison":
        d.ellipse([cx-size*0.16,cy-size*0.1,cx+size*0.16,cy+size*0.22],fill=(120,210,80,255),outline=OUTLINE,width=2)
        for dx in (-0.18,0,0.18):
            d.ellipse([cx+dx*size-size*0.04,cy-size*0.28,cx+dx*size+size*0.04,cy-size*0.2],fill=(150,230,100,255))
    return img

# ============================================================
# UI 元素（9-patch按钮、面板、血条）
# ============================================================
def draw_button(w, h, base, hover=False):
    img = Image.new("RGBA",(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    c = lighten(base,0.2) if hover else base
    d.rounded_rectangle([2,2,w-3,h-3], radius=10, fill=c, outline=OUTLINE, width=3)
    d.rounded_rectangle([5,5,w-6,h//2], radius=8, fill=lighten(c,0.18))  # 顶部高光
    return img

def draw_panel(w, h, base):
    img = Image.new("RGBA",(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([3,3,w-4,h-4], radius=16, fill=base, outline=OUTLINE, width=4)
    d.rounded_rectangle([10,10,w-11,h-11], radius=12, outline=lighten(base,0.25), width=2)
    return img

def draw_bar(w, h, fill_color):
    img = Image.new("RGBA",(w,h),(0,0,0,0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0,0,w-1,h-1], radius=h//2, fill=fill_color, outline=OUTLINE, width=2)
    d.rounded_rectangle([3,2,w-4,h//2], radius=h//3, fill=lighten(fill_color,0.3))
    return img

# ============================================================
# 特效精灵帧
# ============================================================
def draw_effect_frame(size, kind, phase):
    img = new_canvas(size)
    d = ImageDraw.Draw(img)
    cx=cy=size//2
    if kind=="slash":
        a0=140-phase*40
        d.arc([size*0.1,size*0.1,size*0.9,size*0.9], a0, a0+90,
              fill=(255,255,255,int(255*(1-phase*0.6))), width=max(3,int(size*0.1*(1-phase*0.5))))
    elif kind=="hit":
        r=size*0.2*(1+phase)
        for i in range(8):
            a=math.radians(i*45)
            d.line([(cx,cy),(cx+math.cos(a)*r,cy+math.sin(a)*r)],
                   fill=(255,230,150,int(255*(1-phase))),width=2)
    elif kind=="fire":
        for i in range(6):
            fx=cx+math.sin(phase*math.tau+i)*size*0.1
            fy=cy-phase*size*0.3 - i*size*0.04
            rr=size*0.12*(1-phase*0.5)
            col=(255,int(120+phase*100),40,int(220*(1-phase)))
            d.ellipse([fx-rr,fy-rr,fx+rr,fy+rr],fill=col)
    elif kind=="frost":
        r=size*0.35*phase
        d.ellipse([cx-r,cy-r,cx+r,cy+r], outline=(150,220,255,int(220*(1-phase))), width=3)
        for i in range(6):
            a=math.radians(i*60)
            d.line([(cx,cy),(cx+math.cos(a)*r,cy+math.sin(a)*r)],fill=(200,240,255,int(180*(1-phase))),width=2)
    elif kind=="poison":
        for i in range(5):
            px=cx+math.sin(phase*math.tau+i*1.2)*size*0.18
            py=cy-phase*size*0.25+math.cos(i)*size*0.1
            rr=size*0.08
            d.ellipse([px-rr,py-rr,px+rr,py+rr],fill=(120,210,80,int(200*(1-phase))))
    elif kind=="levelup":
        r=size*0.4*phase
        d.ellipse([cx-r,cy-r,cx+r,cy+r], outline=(255,230,120,int(255*(1-phase))), width=max(2,int(size*0.06*(1-phase))))
    return img

# ============================================================
# 主构建流程
# ============================================================
FRAMES = 4  # 每个动作的帧数
CHAR_SIZE = 64
ENEMY_SIZE = 64
ICON_SIZE = 64

# 6 职业配色 + 武器
CLASSES = {
    "warrior":     dict(body=(120,60,50),  skin=(240,200,160), hair=(80,50,30),  accent=(200,170,70),  boots=(70,40,30),  weapon="sword"),
    "ranger":      dict(body=(60,110,70),  skin=(235,195,155), hair=(110,70,40), accent=(150,200,90),  boots=(50,80,50),  weapon="bow"),
    "mage":        dict(body=(70,80,160),  skin=(240,205,170), hair=(200,200,210),accent=(120,180,255), boots=(50,55,110), weapon="staff"),
    "assassin":    dict(body=(50,50,65),   skin=(230,195,160), hair=(30,30,40),  accent=(180,60,80),   boots=(35,35,45),  weapon="dagger"),
    "knight":      dict(body=(160,165,180),skin=(240,200,160), hair=(120,125,140),accent=(230,210,120), boots=(110,115,130),weapon="mace"),
    "necromancer": dict(body=(60,75,70),   skin=(200,210,195), hair=(40,50,55),  accent=(130,220,160), boots=(40,50,48),  weapon="scythe"),
}

# 敌人家族配色
ENEMY_FAMILIES = {
    "skeleton": dict(main=(225,225,210), accent=(180,180,170)),
    "slime":    dict(main=(120,200,110), accent=(80,160,80)),
    "demon":    dict(main=(180,60,50),   accent=(255,180,60)),
    "ice":      dict(main=(140,200,240), accent=(220,245,255)),
    "void":     dict(main=(110,70,150),  accent=(200,120,255)),
    "beast":    dict(main=(140,100,70),  accent=(90,60,40)),
}

# 稀有度配色
RARITY = {
    "common":    (180,180,180),
    "rare":      (74,144,217),
    "epic":      (155,77,202),
    "legendary": (232,163,23),
    "mythic":    (224,49,49),
}

POSES = ["idle","walk","attack","hurt"]

def build_spritesheet(frames):
    """横向拼接帧 -> 一张 sheet"""
    n=len(frames); s=frames[0].width
    sheet=Image.new("RGBA",(s*n,s),(0,0,0,0))
    for i,f in enumerate(frames):
        sheet.alpha_composite(f,(i*s,0))
    return sheet

def build_characters():
    out=ensure(os.path.join(BASE,"characters"))
    for name,pal in CLASSES.items():
        cdir=ensure(os.path.join(out,name))
        for pose in POSES:
            frames=[draw_character_frame(CHAR_SIZE,pal,pose,i/FRAMES,pal["weapon"]) for i in range(FRAMES)]
            build_spritesheet(frames).save(os.path.join(cdir,f"{pose}.png"))
        # 单帧头像（用于UI）
        draw_character_frame(CHAR_SIZE,pal,"idle",0,pal["weapon"]).save(os.path.join(cdir,"portrait.png"))
    print(f"  [OK] 6 职业角色 x {len(POSES)} 动作 x {FRAMES} 帧")

def build_enemies():
    out=ensure(os.path.join(BASE,"enemies"))
    for fam,pal in ENEMY_FAMILIES.items():
        fdir=ensure(os.path.join(out,fam))
        for pose in ["idle","attack"]:
            frames=[draw_enemy_frame(ENEMY_SIZE,fam,pal,pose,i/FRAMES) for i in range(FRAMES)]
            build_spritesheet(frames).save(os.path.join(fdir,f"{pose}.png"))
        # 区域色变体（normal/elite/boss 用 modulate，但也存基础图）
        draw_enemy_frame(ENEMY_SIZE,fam,pal,"idle",0).save(os.path.join(fdir,"static.png"))
    print(f"  [OK] {len(ENEMY_FAMILIES)} 敌人家族 x 2 动作")

def build_icons():
    out=ensure(os.path.join(BASE,"icons"))
    eq=ensure(os.path.join(out,"equipment"))
    items=["sword","helmet","chest","legs","boots","gloves","ring","amulet","staff","bow","potion"]
    for it in items:
        for rar,col in RARITY.items():
            pal=dict(main=col,accent=lighten(col,0.4))
            draw_item_icon(ICON_SIZE,it,pal).save(os.path.join(eq,f"{it}_{rar}.png"))
    sk=ensure(os.path.join(out,"skills"))
    for shp in ["fire","ice","slash","bolt","skull","shield","poison"]:
        pal=dict(main=(80,90,140),accent=(160,180,240))
        draw_skill_icon(ICON_SIZE,shp,pal).save(os.path.join(sk,f"{shp}.png"))
    print(f"  [OK] {len(items)}装备x{len(RARITY)}稀有度 + 7技能图标")

def build_ui():
    out=ensure(os.path.join(BASE,"ui"))
    # 按钮三态
    for state,hov in [("normal",False),("hover",True)]:
        draw_button(200,56,(90,70,120),hov).save(os.path.join(out,f"button_{state}.png"))
    draw_panel(400,300,(40,38,58)).save(os.path.join(out,"panel.png"))
    draw_panel(300,80,(48,44,66)).save(os.path.join(out,"panel_small.png"))
    draw_bar(200,20,(220,60,60)).save(os.path.join(out,"bar_hp.png"))
    draw_bar(200,16,(80,150,230)).save(os.path.join(out,"bar_exp.png"))
    draw_bar(200,16,(90,200,120)).save(os.path.join(out,"bar_mana.png"))
    # 物品格子
    slot=Image.new("RGBA",(72,72),(0,0,0,0))
    sd=ImageDraw.Draw(slot)
    sd.rounded_rectangle([2,2,69,69],radius=8,fill=(55,52,72),outline=OUTLINE,width=3)
    sd.rounded_rectangle([6,6,65,65],radius=6,outline=(90,85,110),width=2)
    slot.save(os.path.join(out,"slot.png"))
    print("  [OK] 按钮/面板/血条/格子 UI")

def build_effects():
    out=ensure(os.path.join(BASE,"effects"))
    EFF_FRAMES=6
    for kind in ["slash","hit","fire","frost","poison","levelup"]:
        frames=[draw_effect_frame(64,kind,i/EFF_FRAMES) for i in range(EFF_FRAMES)]
        build_spritesheet(frames).save(os.path.join(out,f"{kind}.png"))
    print(f"  [OK] 6 种特效动画 x {EFF_FRAMES} 帧")

def build_tiles():
    out=ensure(os.path.join(BASE,"tiles"))
    # 各区域地板 tile（64x64，带格纹）
    floors={
        "crypt":(40,38,55),"swamp":(42,56,38),"forge":(64,38,30),
        "ice":(46,62,80),"void":(48,40,62),"field":(56,64,46),"town":(60,72,52),
    }
    for name,col in floors.items():
        t=Image.new("RGBA",(64,64),col+(255,))
        d=ImageDraw.Draw(t)
        d.rectangle([0,0,63,63],outline=darken(col,0.3),width=2)
        # 随机纹理点
        import random; random.seed(hash(name)%1000)
        for _ in range(8):
            x=random.randint(4,60);y=random.randint(4,60)
            d.ellipse([x,y,x+3,y+3],fill=lighten(col,0.15))
        t.save(os.path.join(out,f"floor_{name}.png"))
        # 障碍物
        ob=new_canvas(64)
        od=ImageDraw.Draw(ob)
        oc=lighten(col,0.25)
        od.rounded_rectangle([10,16,54,58],radius=6,fill=oc,outline=OUTLINE,width=3)
        od.rounded_rectangle([14,20,50,36],radius=4,fill=lighten(oc,0.2))
        ob.save(os.path.join(out,f"obstacle_{name}.png"))
    print(f"  [OK] {len(floors)} 区域地板 + 障碍物")

def main():
    print("="*48)
    print("DarkLoot v3 卡通素材生成")
    print("="*48)
    ensure(BASE)
    build_characters()
    build_enemies()
    build_icons()
    build_ui()
    build_effects()
    build_tiles()
    build_set_auras()       # B4新增:套装光环
    build_boss_entrance()   # B4新增:Boss登场特效
    print("="*48)
    print("全部生成完成")
    print("="*48)

def build_set_auras():
    """B4: 套装光环特效 — 5套装各一个环绕光环PNG"""
    out = ensure(os.path.join(BASE, "sets"))
    SETS = {
        "bone":   (180, 160, 200),  # 紫白骸骨
        "plague": (100, 160, 90),   # 绿瘟疫
        "ember":  (255, 120, 50),   # 橙红烬火
        "frost":  (100, 180, 255),  # 冰蓝
        "void":   (150, 80, 200),   # 虚空紫
    }
    size = 128
    for set_name, col in SETS.items():
        img = new_canvas(size)
        d = ImageDraw.Draw(img)
        # 三环渐变光环
        for i, r in enumerate([60, 52, 44]):
            alpha = int(120 - i * 30)
            c = col + (alpha,)
            d.ellipse([size//2-r, size//2-r, size//2+r, size//2+r], fill=None, outline=c, width=6-i*2)
        # 光点装饰(8个)
        for j in range(8):
            angle = j * TAU / 8
            x = size//2 + int(cos(angle) * 54)
            y = size//2 + int(sin(angle) * 54)
            d.ellipse([x-4, y-4, x+4, y+4], fill=lighten(col, 0.4))
        img.save(os.path.join(out, f"aura_{set_name}.png"))
    print(f"  [OK] 5 套装光环")

def build_boss_entrance():
    """B4: Boss 登场特效 — 6 个 Boss 登场像素图(128x128)"""
    out = ensure(os.path.join(BASE, "bosses"))
    BOSSES = {
        # boss_id: (主色, 形状提示)
        "bone_lord":     ((200, 180, 220), "skull"),
        "brood_mother":  ((100, 140, 80),  "blob"),
        "ember_lord":    ((255, 100, 40),  "knight"),
        "frost_lich":    ((120, 180, 255), "staff"),
        "void_child":    ((140, 80, 180),  "orb"),
        "abyss_herald":  ((180, 60, 60),   "warrior"),
    }
    size = 128
    for boss_id, (col, hint) in BOSSES.items():
        img = new_canvas(size)
        d = ImageDraw.Draw(img)
        # 简化:暗黑剪影 + 发光描边
        if hint == "skull":
            # 骷髅头
            d.ellipse([28, 24, 100, 88], fill=darken(col, 0.6), outline=col, width=4)
            # 眼洞
            d.ellipse([42, 42, 54, 58], fill=(0,0,0), outline=lighten(col,0.3), width=2)
            d.ellipse([74, 42, 86, 58], fill=(0,0,0), outline=lighten(col,0.3), width=2)
        elif hint == "blob":
            # 不规则团块
            pts = [(40,90), (25,60), (45,30), (83,30), (103,60), (88,90), (64,104)]
            d.polygon(pts, fill=darken(col,0.5), outline=col)
            d.line(pts + [pts[0]], fill=lighten(col,0.3), width=4, joint="curve")
        elif hint == "knight":
            # 武装骑士剪影
            d.ellipse([44, 20, 84, 50], fill=darken(col,0.6), outline=col, width=4)  # 头盔
            d.rounded_rectangle([34, 48, 94, 110], radius=8, fill=darken(col,0.5), outline=col, width=4)  # 身躯
        elif hint == "staff":
            # 法杖巫妖
            d.ellipse([44, 22, 84, 58], fill=darken(col,0.6), outline=col, width=3)  # 头部
            d.rounded_rectangle([36, 56, 92, 108], radius=10, fill=darken(col,0.5), outline=col, width=3)  # 袍
            # 法杖
            d.line([(100,60),(110,105)], fill=lighten(col,0.4), width=6)
            d.ellipse([106,56,114,64], fill=lighten(col,0.5))
        elif hint == "orb":
            # 虚空球体
            for r in [48, 38, 28]:
                alpha = int(200 - (48-r)*3)
                d.ellipse([64-r, 64-r, 64+r, 64+r], fill=None, outline=col+(alpha,), width=6)
        elif hint == "warrior":
            # 持斧战士
            d.ellipse([46, 24, 82, 54], fill=darken(col,0.6), outline=col, width=3)
            d.rounded_rectangle([38, 52, 90, 112], radius=8, fill=darken(col,0.5), outline=col, width=4)
        img = img.filter(ImageFilter.GaussianBlur(1.5))  # 轻微模糊增加神秘感
        img.save(os.path.join(out, f"entrance_{boss_id}.png"))
    print(f"  [OK] {len(BOSSES)} Boss 登场像素图")
    build_effects()
    build_tiles()
    print("="*48)
    print(f"全部完成！输出目录: {BASE}")
    print("="*48)

if __name__ == "__main__":
    main()

PLACEHOLDER3 = "END"
