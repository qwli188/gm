# 工程化升级总结 2026-06-08

## 已完成

### ✅ 功能 Bug 修复（3个）
1. **局外强化系统失效** - Player.gd meta 强化 ID 不匹配 + 属性膨胀
2. **on_hit_chance 词缀断链** - EquipmentSystem/CombatSystem/Enemy 添加触发式词缀支持
3. **冰冻/减速计时器冲突** - Enemy 拆分独立计时器

**交付物**: BUGFIX_REPORT_2026-06-08.md

---

## 工程化升级方案

### 1. ConfigLoader 索引化 (O(n)→O(1))

**改动内容**:
- 添加 7 个索引字典：_equipment_index, _affixes_index, _skills_index, _enemies_index, _classes_index, _sets_index, _dungeons_index
- 实现 _build_indexes() 函数：在 load_all_configs() 和 reload_config() 后调用
- 改造 7 个查找函数为 O(1) 索引查找：
  - get_equipment_by_id(id) → return _equipment_index.get(id, {})
  - get_affix_by_id(id) → return _affixes_index.get(id, {})
  - get_skill_by_id(id) → return _skills_index.get(id, {})
  - get_enemy_by_id(id) → return _enemies_index.get(id, {})
  - get_class_by_id(id) → return _classes_index.get(id, {})
  - get_set_by_id(id) → return _sets_index.get(id, {})
  - get_dungeon_by_id(id) → return _dungeons_index.get(id, {})

**收益**: 掉落/技能释放等高频调用点性能提升

**状态**: 需重新应用（之前改动被 git checkout 清除）

---

### 2. balance_simulator.py 统一公式

**当前问题**:
```python
# tools/balance_simulator.py 硬编码
CRIT_MULTIPLIER_BASE = 1.5
ARMOR_CONSTANT = 100.0
```

而 project/src/config/balance.json 的 damage_formula 也定义了这些值，两边需手工同步。

**改动方案**:
```python
# MockPlayer.__init__() 改为从 balance.json 读取
balance_path = Path(config_root) / "balance.json"
balance = json.loads(balance_path.read_text(encoding='utf-8'))
self.crit_multiplier = balance["damage_formula"]["crit_multiplier_base"]
self.armor_constant = balance.get("damage_formula", {}).get("armor_constant", 100.0)
```

**收益**: 消除双份公式，模拟器不失真

---

### 3. 纯 Node 配置校验器 + pre-commit hook

**创建文件**: tools/validate_config.js

**实现检查**:
1. 引用完整性：装备→词缀/套装，职业→起手武器，技能→class，副本→wave_set，波次→敌人
2. ID 唯一性：所有配置表不能有重复 ID
3. 必填字段：按 _schema_standard.json 的 config_required_fields 检查

**创建 hook**: .git/hooks/pre-commit
```bash
#!/bin/bash
echo "🔍 Validating config files..."
node tools/validate_config.js
if [ $? -ne 0 ]; then
  echo "❌ Config validation failed. Fix errors before committing."
  exit 1
fi
echo "✅ Config validation passed"
```

**收益**: 改配置即时拦截错误，脱离 Godot headless 依赖

---

## 实施建议

由于 ConfigLoader.gd 的索引化改造已被 git checkout 清除，且涉及多处修改（~60行代码），**建议手工重新应用时使用以下策略之一**：

**方案 A: 逐步应用**（稳妥但耗时）
1. 添加索引字段声明（7行）
2. 实现 _build_indexes() 函数（~45行）
3. 改造 7 个查找函数（每个 1-3 行替换）
4. 在 load_all_configs() 和 reload_config() 添加 _build_indexes() 调用

**方案 B: 对比 patch 应用**（快速但需验证）
1. 查看 git 历史中之前的索引化改动
2. 用 git apply 或手工应用 patch

**方案 C: 文档交付**（如果时间紧张）
1. 将索引化改造方案详细文档化（包含完整代码片段）
2. 交付给开发者手工应用
3. 优先完成 balance_simulator 和校验器（改动量小，收益明显）

---

## 当前状态

- ✅ 3 个功能 Bug 已修复并验证
- ⏸️ ConfigLoader 索引化方案已设计，待重新应用
- ⏳ balance_simulator 公式统一待实施
- ⏳ 纯 Node 校验器待创建

---

**建议下一步**: 
1. 如果有充足时间，重新应用 ConfigLoader 索引化（方案 A 或 B）
2. 如果时间紧张，优先完成 balance_simulator 和校验器（改动小，独立验证，不依赖 Godot）
