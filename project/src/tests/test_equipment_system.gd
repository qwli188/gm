extends Node
## EquipmentSystem 单元测试套件
## 使用 mock 数据，不依赖 ConfigLoader
## 调用 run_tests() 运行全部测试并打印报告

# ============ Mock 数据 ============

# 模拟的套装配置（白骨套装）
var mock_sets: Dictionary = {
	"set_bone":
	{
		"id": "set_bone",
		"display_name": "白骨套装",
		"bonuses":
		[
			{"pieces": 2, "stats": {"lifesteal": 0.05}, "effects": {}},
			{
				"pieces": 4,
				"stats": {"damage": 30.0, "crit_chance": 0.1},
				"effects": {"bone_explosion": true}
			}
		]
	}
}

# 模拟的词缀配置
var mock_affixes: Dictionary = {
	"affix_freeze_01":
	{
		"id": "affix_freeze_01",
		"display_name": "寒冰之触",
		"effect": {"kind": "freeze", "chance": 0.15, "duration": 2.0}
	},
	"affix_mult_damage":
	{
		"id": "affix_mult_damage",
		"display_name": "伤害倍率",
		"effect": {"kind": "mult_stat", "stat": "damage", "value": 0.25}
	}
}


# 用于测试的 mock 装备数据
func _make_weapon(dmg: float, set_id: String = "", affixes: Array = []) -> Dictionary:
	return {
		"id": "test_weapon",
		"slot": "weapon",
		"display_name": "测试武器",
		"rarity": "rare",
		"set_id": set_id,
		"base_stats": {"damage": dmg, "crit_chance": 0.05},
		"fixed_affixes": affixes
	}


func _make_helmet(armor: float, set_id: String = "", affixes: Array = []) -> Dictionary:
	return {
		"id": "test_helmet",
		"slot": "helmet",
		"display_name": "测试头盔",
		"rarity": "rare",
		"set_id": set_id,
		"base_stats": {"armor": armor, "max_hp": 50.0},
		"fixed_affixes": affixes
	}


func _make_chest(armor: float, set_id: String = "", affixes: Array = []) -> Dictionary:
	return {
		"id": "test_chest",
		"slot": "chest",
		"display_name": "测试胸甲",
		"rarity": "epic",
		"set_id": set_id,
		"base_stats": {"armor": armor, "max_hp": 100.0},
		"fixed_affixes": affixes
	}


func _make_legs(armor: float, set_id: String = "", affixes: Array = []) -> Dictionary:
	return {
		"id": "test_legs",
		"slot": "legs",
		"display_name": "测试腿甲",
		"rarity": "rare",
		"set_id": set_id,
		"base_stats": {"armor": armor, "max_hp": 40.0},
		"fixed_affixes": affixes
	}


func _make_boots(armor: float, set_id: String = "", affixes: Array = []) -> Dictionary:
	return {
		"id": "test_boots",
		"slot": "boots",
		"display_name": "测试靴子",
		"rarity": "rare",
		"set_id": set_id,
		"base_stats": {"armor": armor, "move_speed": 0.1},
		"fixed_affixes": affixes
	}


# ============ 被测系统（内联版，避免 ConfigLoader 依赖） ============

# 模拟 EquipmentSystem 的核心逻辑，用 mock 数据替代 ConfigLoader 调用
const SLOTS = ["weapon", "helmet", "chest", "legs", "boots", "gloves", "ring", "amulet"]

var _equipped: Dictionary = {}
var _active_sets: Dictionary = {}


func _reset():
	_equipped = {}
	_active_sets = {}
	for slot in SLOTS:
		_equipped[slot] = null


func _mock_equip(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false
	var slot = item_data.get("slot", "weapon")
	if not _equipped.has(slot):
		return false
	_equipped[slot] = item_data
	_mock_recompute_sets()
	return true


func _mock_unequip(slot: String):
	if _equipped.has(slot):
		_equipped[slot] = null
		_mock_recompute_sets()


func _mock_recompute_sets():
	var counts = {}
	for slot in _equipped:
		var item = _equipped[slot]
		if item == null:
			continue
		var sid = item.get("set_id", "")
		if sid != "":
			counts[sid] = counts.get(sid, 0) + 1
	_active_sets = counts


func _mock_get_set_bonuses() -> Dictionary:
	var bonuses = {}
	for sid in _active_sets:
		var pieces = _active_sets[sid]
		var set_data = mock_sets.get(sid, {})
		if set_data.is_empty():
			continue
		for tier in set_data.get("bonuses", []):
			var req = tier.get("pieces", 99)
			if pieces >= req:
				_mock_merge_set_tier(bonuses, tier)
	return bonuses


func _mock_merge_set_tier(bonuses: Dictionary, tier: Dictionary):
	var stats = tier.get("stats", {})
	for k in stats:
		bonuses[k] = bonuses.get(k, 0.0) + stats[k]
	var effects = tier.get("effects", {})
	for k in effects:
		bonuses["effect_" + k] = effects[k]


func _mock_get_total_stats() -> Dictionary:
	var total = {
		"damage": 0.0,
		"max_hp": 0.0,
		"armor": 0.0,
		"crit_chance": 0.0,
		"crit_damage": 0.0,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 1.0,
		"hp_regen": 0.0
	}
	for slot in _equipped:
		var item = _equipped[slot]
		if item == null:
			continue
		var stats = item.get("base_stats", {})
		total["damage"] += stats.get("damage", 0)
		total["max_hp"] += stats.get("max_hp", 0)
		total["armor"] += stats.get("armor", 0)
		total["crit_chance"] += stats.get("crit_chance", 0)
		total["crit_damage"] += stats.get("crit_damage", 0)
		total["hp_regen"] += stats.get("hp_regen", 0)
		if stats.has("attack_speed"):
			total["attack_speed_mult"] *= stats["attack_speed"]
		if stats.has("move_speed"):
			total["move_speed_mult"] *= (1.0 + stats["move_speed"])
		_mock_apply_item_affix_stats(item, total)

	var set_bonus = _mock_get_set_bonuses()
	for stat_key in set_bonus:
		if stat_key.ends_with("_mult"):
			total[stat_key] = total.get(stat_key, 1.0) * (1.0 + set_bonus[stat_key])
		else:
			total[stat_key] = total.get(stat_key, 0.0) + set_bonus[stat_key]
	return total


func _mock_apply_item_affix_stats(item: Dictionary, total: Dictionary):
	for affix_id in item.get("fixed_affixes", []):
		var affix = mock_affixes.get(affix_id, {})
		var eff = affix.get("effect", {})
		if eff.get("kind", "") == "add_stat":
			var stat = eff.get("stat", "")
			if total.has(stat):
				total[stat] += eff.get("value", 0)


func _mock_get_combat_effects() -> Dictionary:
	var effects = {}
	for slot in _equipped:
		var item = _equipped[slot]
		if item == null:
			continue
		for affix_id in item.get("fixed_affixes", []):
			var affix = mock_affixes.get(affix_id, {})
			if affix.is_empty():
				continue
			_mock_merge_affix_effect(effects, affix)
	var set_bonus = _mock_get_set_bonuses()
	for k in set_bonus:
		if k.begins_with("effect_"):
			effects[k.trim_prefix("effect_")] = set_bonus[k]
	return effects


func _mock_merge_affix_effect(effects: Dictionary, affix: Dictionary):
	var eff = affix.get("effect", {})
	var kind = eff.get("kind", "")
	match kind:
		"lifesteal":
			effects["lifesteal"] = effects.get("lifesteal", 0.0) + eff.get("value", 0)
		"add_damage":
			effects["added_damage"] = effects.get("added_damage", 0.0) + eff.get("value", 0)
			effects["damage_type"] = eff.get("damage_type", "physical")
		"ignite":
			effects["ignite_dps"] = effects.get("ignite_dps", 0.0) + eff.get("dps", 0)
			effects["ignite_duration"] = max(
				effects.get("ignite_duration", 0.0), eff.get("duration", 0)
			)
		"poison":
			effects["poison_dps"] = effects.get("poison_dps", 0.0) + eff.get("dps", 0)
			effects["poison_duration"] = max(
				effects.get("poison_duration", 0.0), eff.get("duration", 0)
			)
		"freeze":
			effects["freeze_chance"] = effects.get("freeze_chance", 0.0) + eff.get("chance", 0)
			effects["freeze_duration"] = max(
				effects.get("freeze_duration", 0.0), eff.get("duration", 0)
			)
		"slow":
			effects["slow_percent"] = effects.get("slow_percent", 0.0) + eff.get("percent", 0)
			effects["slow_duration"] = max(
				effects.get("slow_duration", 0.0), eff.get("duration", 0)
			)
		"stun":
			effects["stun_chance"] = effects.get("stun_chance", 0.0) + eff.get("chance", 0)
			effects["stun_duration"] = max(
				effects.get("stun_duration", 0.0), eff.get("duration", 0)
			)
		"mult_stat":
			var stat = eff.get("stat", "")
			effects[stat + "_mult"] = effects.get(stat + "_mult", 0.0) + eff.get("value", 0)
		_:
			pass


# ============ 测试函数 ============


func test_equip_item() -> bool:
	_reset()
	var weapon = _make_weapon(50.0)
	var ok = _mock_equip(weapon)
	if not ok:
		print("  FAIL: equip_item returned false")
		return false
	if _equipped["weapon"] == null:
		print("  FAIL: equipped_items['weapon'] is null after equip")
		return false
	if _equipped["weapon"]["id"] != "test_weapon":
		print("  FAIL: equipped weapon id mismatch, got: %s" % _equipped["weapon"]["id"])
		return false
	if _equipped["weapon"]["slot"] != "weapon":
		print("  FAIL: equipped weapon slot mismatch, got: %s" % _equipped["weapon"]["slot"])
		return false
	# 其他槽位仍为 null
	if _equipped["helmet"] != null:
		print("  FAIL: helmet should be null, got: %s" % str(_equipped["helmet"]))
		return false
	return true


func test_unequip_item() -> bool:
	_reset()
	var weapon = _make_weapon(50.0)
	_mock_equip(weapon)
	_mock_unequip("weapon")
	if _equipped["weapon"] != null:
		print(
			"  FAIL: weapon slot should be null after unequip, got: %s" % str(_equipped["weapon"])
		)
		return false
	return true


func test_set_bonus_2pieces() -> bool:
	_reset()
	# 装备2件白骨套装
	_mock_equip(_make_weapon(40.0, "set_bone"))
	_mock_equip(_make_helmet(20.0, "set_bone"))

	if _active_sets.get("set_bone", 0) != 2:
		print(
			"  FAIL: active_sets['set_bone'] should be 2, got: %d" % _active_sets.get("set_bone", 0)
		)
		return false

	var bonuses = _mock_get_set_bonuses()
	if not bonuses.has("lifesteal"):
		print(
			(
				"  FAIL: 2-piece set bonus should contain 'lifesteal', got keys: %s"
				% str(bonuses.keys())
			)
		)
		return false
	if not is_equal_approx(bonuses["lifesteal"], 0.05):
		print("  FAIL: lifesteal should be 0.05, got: %f" % bonuses["lifesteal"])
		return false
	# 4件阶梯不应激活
	if bonuses.has("effect_bone_explosion"):
		print("  FAIL: 4-piece effect 'bone_explosion' should NOT be active with 2 pieces")
		return false
	return true


func test_set_bonus_4pieces() -> bool:
	_reset()
	# 装备4件白骨套装
	_mock_equip(_make_weapon(40.0, "set_bone"))
	_mock_equip(_make_helmet(20.0, "set_bone"))
	_mock_equip(_make_chest(30.0, "set_bone"))
	_mock_equip(_make_legs(15.0, "set_bone"))

	if _active_sets.get("set_bone", 0) != 4:
		print(
			"  FAIL: active_sets['set_bone'] should be 4, got: %d" % _active_sets.get("set_bone", 0)
		)
		return false

	var bonuses = _mock_get_set_bonuses()
	# 2件阶梯仍应激活
	if not bonuses.has("lifesteal"):
		print(
			(
				"  FAIL: 2-piece lifesteal should still be active at 4 pieces, got keys: %s"
				% str(bonuses.keys())
			)
		)
		return false
	# 4件阶梯加成
	if not bonuses.has("damage"):
		print("  FAIL: 4-piece bonus should contain 'damage', got keys: %s" % str(bonuses.keys()))
		return false
	if not is_equal_approx(bonuses["damage"], 30.0):
		print("  FAIL: 4-piece damage bonus should be 30.0, got: %f" % bonuses["damage"])
		return false
	if not bonuses.has("crit_chance"):
		print(
			"  FAIL: 4-piece bonus should contain 'crit_chance', got keys: %s" % str(bonuses.keys())
		)
		return false
	if not bonuses.has("effect_bone_explosion"):
		print(
			(
				"  FAIL: 4-piece effect 'bone_explosion' should be active, got keys: %s"
				% str(bonuses.keys())
			)
		)
		return false
	return true


func test_total_stats_aggregation() -> bool:
	_reset()
	# 装备3件物品（无套装），检查 damage 汇总
	var weapon = _make_weapon(50.0)  # damage=50
	var helmet = _make_helmet(20.0)  # armor=20, max_hp=50
	var chest = _make_chest(35.0)  # armor=35, max_hp=100

	_mock_equip(weapon)
	_mock_equip(helmet)
	_mock_equip(chest)

	var total = _mock_get_total_stats()

	# damage = weapon only (50)
	if not is_equal_approx(total["damage"], 50.0):
		print("  FAIL: total damage should be 50.0, got: %f" % total["damage"])
		return false

	# armor = helmet(20) + chest(35) = 55
	var expected_armor = 20.0 + 35.0
	if not is_equal_approx(total["armor"], expected_armor):
		print("  FAIL: total armor should be %f, got: %f" % [expected_armor, total["armor"]])
		return false

	# max_hp = helmet(50) + chest(100) = 150
	var expected_hp = 50.0 + 100.0
	if not is_equal_approx(total["max_hp"], expected_hp):
		print("  FAIL: total max_hp should be %f, got: %f" % [expected_hp, total["max_hp"]])
		return false

	# crit_chance = weapon(0.05) only
	if not is_equal_approx(total["crit_chance"], 0.05):
		print("  FAIL: total crit_chance should be 0.05, got: %f" % total["crit_chance"])
		return false

	return true


func test_affix_freeze_keys() -> bool:
	_reset()
	# 装备含 freeze 词缀的武器
	var weapon = _make_weapon(45.0, "", ["affix_freeze_01"])
	_mock_equip(weapon)

	var effects = _mock_get_combat_effects()

	if not effects.has("freeze_chance"):
		print(
			(
				"  FAIL: combat_effects should contain 'freeze_chance', got keys: %s"
				% str(effects.keys())
			)
		)
		return false
	if not effects.has("freeze_duration"):
		print(
			(
				"  FAIL: combat_effects should contain 'freeze_duration', got keys: %s"
				% str(effects.keys())
			)
		)
		return false
	if not is_equal_approx(effects["freeze_chance"], 0.15):
		print("  FAIL: freeze_chance should be 0.15, got: %f" % effects["freeze_chance"])
		return false
	if not is_equal_approx(effects["freeze_duration"], 2.0):
		print("  FAIL: freeze_duration should be 2.0, got: %f" % effects["freeze_duration"])
		return false
	return true


func test_affix_mult_stat() -> bool:
	_reset()
	# 装备含 mult_stat 词缀的武器
	var weapon = _make_weapon(60.0, "", ["affix_mult_damage"])
	_mock_equip(weapon)

	var effects = _mock_get_combat_effects()

	if not effects.has("damage_mult"):
		print(
			(
				"  FAIL: combat_effects should contain 'damage_mult', got keys: %s"
				% str(effects.keys())
			)
		)
		return false
	if not is_equal_approx(effects["damage_mult"], 0.25):
		print("  FAIL: damage_mult should be 0.25, got: %f" % effects["damage_mult"])
		return false
	return true


# ============ 测试运行器 ============


func run_tests():
	print("")
	print("========================================")
	print("  EquipmentSystem Test Suite")
	print("========================================")

	var tests = [
		["test_equip_item", Callable(self, "test_equip_item")],
		["test_unequip_item", Callable(self, "test_unequip_item")],
		["test_set_bonus_2pieces", Callable(self, "test_set_bonus_2pieces")],
		["test_set_bonus_4pieces", Callable(self, "test_set_bonus_4pieces")],
		["test_total_stats_aggregation", Callable(self, "test_total_stats_aggregation")],
		["test_affix_freeze_keys", Callable(self, "test_affix_freeze_keys")],
		["test_affix_mult_stat", Callable(self, "test_affix_mult_stat")],
	]

	var passed = 0
	var failed = 0
	var results: Array = []

	for entry in tests:
		var test_name: String = entry[0]
		var test_fn: Callable = entry[1]
		print("  RUN  %s" % test_name)
		var ok: bool = test_fn.call()
		if ok:
			passed += 1
			results.append("  PASS %s" % test_name)
			print("  PASS %s" % test_name)
		else:
			failed += 1
			results.append("  FAIL %s" % test_name)
			print("  FAIL %s" % test_name)

	print("----------------------------------------")
	print("  Results: %d passed, %d failed, %d total" % [passed, failed, passed + failed])
	if failed == 0:
		print("  ALL TESTS PASSED")
	else:
		print("  SOME TESTS FAILED")
	print("========================================")
	print("")

	var failed_names: Array = []
	for r in results:
		if r.begins_with("  FAIL"):
			failed_names.append("equipment:" + r.substr(6))
	return {"pass": passed, "fail": failed, "failed_names": failed_names}
