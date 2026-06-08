# Bug 修复报告 2026-06-08

## 修复概览

修复了 3 个功能性 bug,影响局外强化系统、词缀系统、敌人状态效果。所有修复已通过配置引用完整性校验。

---

## 问题 1：局外强化系统完全失效 ❌ 已修复 ✅

### 根因
**三方数据契约不一致**:
- `balance.json` 定义 5 种强化:`perm_hp`, `perm_damage`, `perm_attack_speed`, `perm_crit_chance`, `perm_move_speed`
- `Town.gd` 读 balance.json 写入 `GameState.meta_upgrades` ✅ 正确
- `Player.gd` 调用 `get_meta_bonus("perm_max_hp")` ❌ ID 不匹配 (balance 里叫 `perm_hp`)
- `Player.gd` 原本写 `base_damage += perm_damage` ❌ 每次穿脱装备累加,属性膨胀

### 影响
- 玩家在铁匠铺升级体魄/力量,`meta_upgrades` 正确写入
- 但 `perm_damage` 重复累加导致伤害膨胀,`perm_hp` ID 不匹配返回 0
- **5 种强化中只有 perm_damage 生效(但数值错误),其余 4 种完全失效**

### 修复
**文件**: [project/src/scripts/Player.gd](project/src/scripts/Player.gd#L94-L131)

1. **防膨胀**: meta 强化不再写回 `base_*`,在 `recalculate_stats()` 内累加到最终值
2. **修正 ID**: `perm_max_hp` → `perm_hp`
3. **补全 4 种强化**: 添加 `perm_attack_speed`、`perm_crit_chance`、`perm_move_speed` 的读取和应用

```gdscript
# 修复前 (错误):
base_damage += perm_damage  # 每次 recalc 都累加,膨胀
base_max_hp += perm_max_hp  # ID 不匹配,永远返回 0

# 修复后 (正确):
damage += perm_damage       # 累加到最终值,不修改 base
max_hp += perm_hp           # 修正 ID
attack_speed *= (1.0 + perm_attack_speed)
crit_chance += perm_crit
move_speed *= (1.0 + perm_move)
```

---

## 问题 2：`on_hit_chance` 词缀整条链断裂 ❌ 已修复 ✅

### 根因
**词缀系统只处理直接效果,未处理触发式效果**:
- 配置里有 3 个 `kind="on_hit_chance"` 词缀(冰封/霜缚/墓冢恐惧)
- effect 结构:`{chance:0.15, sub_effect:{kind:"freeze", duration:1.5}}`
- `EquipmentSystem._merge_affix_effect` 的 `match kind:` 没有 `on_hit_chance` 分支
- 这 3 个词缀被 8 件装备引用,但属性汇总时被 `_:pass` 吞掉

### 影响
- `affix_grave_chill` (12% 眩晕)、`affix_freeze` (15% 冰冻)、`affix_chill` (25% 减速) 完全无效
- 枯骨巨锤、白骨君王战靴、霜寒面盔等 8 件装备的控制词缀形同虚设

### 修复
**文件**: [project/src/autoload/EquipmentSystem.gd](project/src/autoload/EquipmentSystem.gd#L177-L219)

添加 `on_hit_chance` 展开逻辑,将 `sub_effect` 递归展开为对应的 `*_chance` + `duration`:

```gdscript
"on_hit_chance":
    var chance = eff.get("chance", 0.0)
    var sub = eff.get("sub_effect", {})
    var sub_kind = sub.get("kind", "")
    match sub_kind:
        "freeze":
            effects["freeze_chance"] += chance
            effects["freeze_duration"] = max(effects["freeze_duration"], sub.get("duration", 0))
        "slow":
            effects["slow_chance"] += chance
            effects["slow_percent"] = sub.get("value", 0.0)
            effects["slow_duration"] = max(effects["slow_duration"], sub.get("duration", 0))
        "stun":
            effects["stun_chance"] += chance
            effects["stun_duration"] = max(effects["stun_duration"], sub.get("duration", 0))
```

**文件**: [project/src/autoload/CombatSystem.gd](project/src/autoload/CombatSystem.gd#L41-L93)

添加眩晕触发和减速概率触发:

```gdscript
# 支持 slow_chance 概率触发(之前只有 slow_percent 必触发)
var slow_chance = attacker_stats.get("slow_chance", 0.0)
if slow_percent > 0:
    if slow_chance > 0:
        if randf() < slow_chance:
            trigger_slow(target, slow_percent, slow_duration)
    else:
        trigger_slow(target, slow_percent, slow_duration)

# 新增眩晕触发
var stun_chance = attacker_stats.get("stun_chance", 0.0)
var stun_duration = attacker_stats.get("stun_duration", 0.0)
if stun_chance > 0 and randf() < stun_chance:
    trigger_stun(target, stun_duration)

func trigger_stun(target: Node2D, duration: float):
    if not target.has_method("apply_stun"):
        return
    target.apply_stun(duration)
```

**文件**: [project/src/scripts/Enemy.gd](project/src/scripts/Enemy.gd#L172-L240)

添加眩晕状态处理:

```gdscript
var stun_timer: float = 0.0
var is_stunned: bool = false

func apply_stun(duration: float):
    is_stunned = true
    stun_timer = duration
    if not is_frozen:
        base_move_speed = move_speed
    move_speed = 0

# chase_player 里检查眩晕
if is_frozen or is_stunned:
    effective_speed = 0

# _process 里独立计时
if stun_timer > 0:
    stun_timer -= delta
    if stun_timer <= 0:
        is_stunned = false
        if not is_frozen:
            move_speed = base_move_speed
```

---

## 问题 3：冰冻和减速共用计时器(互相覆盖) ❌ 已修复 ✅

### 根因
`Enemy.apply_slow` 写 `freeze_timer`,和 `apply_freeze` 共用:

```gdscript
func apply_slow(slow_percent: float, duration: float):
    slow_multiplier = 1.0 - slow_percent
    freeze_timer = duration  # ← 覆盖冰冻剩余时间
```

### 影响
- 同时中冰冻+减速时,后者覆盖前者的 duration
- 先结束的清 `freeze_timer` 时另一个也跟着结束

### 修复
**文件**: [project/src/scripts/Enemy.gd](project/src/scripts/Enemy.gd#L172-L240)

拆成两个独立计时器:

```gdscript
var freeze_timer: float = 0.0
var slow_timer: float = 0.0  # 新增

func apply_slow(slow_percent: float, duration: float):
    slow_multiplier = 1.0 - slow_percent
    slow_timer = duration  # 使用独立计时器

# _process 里分别处理
if freeze_timer > 0:
    freeze_timer -= delta
    if freeze_timer <= 0:
        # 恢复冰冻

if slow_timer > 0:
    slow_timer -= delta
    if slow_timer <= 0:
        slow_multiplier = 1.0
```

---

## 相关修复：测试和文档

### 更新测试
**文件**: [project/src/tests/test_player.gd](project/src/tests/test_player.gd#L158-L176)

- 修正 `test_get_meta_bonus_call`:断言 meta 强化应用到**最终属性**,而非 base
- 修正 meta id:`perm_max_hp` → `perm_hp`

### 更新 schema 契约
**文件**: [project/src/config/_schema_standard.json](project/src/config/_schema_standard.json#L40-L58)

- `affix_kinds.implemented` 添加 `"on_hit_chance"`
- `effect_structure` 添加 `on_hit_chance` 定义
- `output_keys_mapping` 添加 `slow_chance` 和 `on_hit_chance` 说明

---

## 验证结果

### 配置引用完整性 ✅
```
装备 108 → 词缀 31 (引用有效)
装备 108 → 套装 5 (引用有效)
职业 6 → 起手武器 (引用有效)
技能 42 → class (引用有效)
副本 21 → wave_set (引用有效)
波次 21 → 敌人 252 引用 (引用有效)
```

### on_hit_chance 词缀使用情况 ✅
```
affix_grave_chill → 12% 触发 stun 持续 1s
affix_freeze → 15% 触发 freeze 持续 1.5s
affix_chill → 25% 触发 slow 持续 2s

使用这些词缀的装备: 8 件
- 枯骨巨锤 (affix_grave_chill)
- 白骨君王尸行战靴 (affix_grave_chill)
- 霜寒面盔 (affix_freeze)
- 踏霜战靴 (affix_chill)
- 寒星指环 (affix_freeze)
- ...
```

### meta id 对齐 ✅
```
balance.json: perm_hp, perm_damage, perm_attack_speed, perm_crit_chance, perm_move_speed
Player.gd:    perm_hp, perm_damage, perm_attack_speed, perm_crit_chance, perm_move_speed
✅ 完全匹配
```

### CombatSystem-Enemy 契约 ✅
```
CombatSystem 调用:
- target.apply_ignite()
- target.apply_poison()
- target.apply_freeze()
- target.apply_slow()
- target.apply_stun()  ← 新增

Enemy 实现:
- func apply_ignite()
- func apply_poison()
- func apply_freeze()
- func apply_slow()
- func apply_stun()  ← 新增
```

---

## 影响面评估

### 玩家体验改善
1. **局外强化真正生效** — 5 种强化全部正确应用,铁匠铺花钱有效果
2. **8 件装备控制词缀生效** — 冰封/霜缚/墓冢恐惧不再是摆设
3. **状态效果互不干扰** — 冰冻+减速可正常共存

### 回归风险
- **低** — 修改严格遵循现有契约,未改变数据结构
- 所有改动局限在属性计算和状态应用,不涉及 UI/场景/掉落

### 测试建议
1. 铁匠铺升级体魄/力量,进副本验证血量/伤害提升
2. 装备带 `affix_freeze`/`affix_chill`/`affix_grave_chill` 的装备,验证控制生效
3. 同时触发冰冻+减速,验证两者独立计时

---

## 修改文件清单

```
project/src/scripts/Player.gd              (局外强化修复)
project/src/autoload/EquipmentSystem.gd    (on_hit_chance 展开)
project/src/autoload/CombatSystem.gd       (stun/slow_chance 触发)
project/src/scripts/Enemy.gd               (stun 状态 + 拆分计时器)
project/src/tests/test_player.gd           (测试适配)
project/src/config/_schema_standard.json   (文档更新)
```

---

**修复时间**: 2026-06-08  
**验证状态**: ✅ 配置引用完整性通过  
**回归测试**: 待人工验收
