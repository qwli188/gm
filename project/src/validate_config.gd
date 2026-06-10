extends SceneTree
## 配置完整性校验脚本 - 用 godot --headless -s res://validate_config.gd 运行
## 检查引用完整性、数值合理性、字段齐全性、稀有度阶梯、重复ID

var errors: Array = []
var warnings: Array = []
var schema: Dictionary = {}
var ConfigLoader: Node = null

func _initialize() -> void:
	await process_frame
	await process_frame
	ConfigLoader = root.get_node_or_null("ConfigLoader")
	if ConfigLoader == null:
		print("[配置校验] 无法获取 ConfigLoader autoload")
		quit(1)
		return

	print("\n========== 配置校验开始 ==========")
	schema = _load_schema()

	if schema.is_empty():
		errors.append("_schema_standard.json 缺失或无法读取")
		_print_results()
		quit(1)
		return

	_validate_schema_compliance()
	_validate_duplicate_ids()
	_validate_cross_references()
	_validate_value_ranges()
	_validate_rarity_progression()
	_validate_schema_whitelist()
	_print_results()

	quit(1 if errors.size() > 0 else 0)

## 1. 检查所有配置是否符合 schema 定义的必填字段
func _validate_schema_compliance():
	print("[检查] 字段完整性...")

	var required_all = schema.get("config_required_fields", {}).get("all", [])
	var required_equipment = schema.get("config_required_fields", {}).get("equipment", [])
	var required_affixes = schema.get("config_required_fields", {}).get("affixes", [])
	var required_skills = schema.get("config_required_fields", {}).get("skills", [])
	var required_enemies = schema.get("config_required_fields", {}).get("enemies", [])
	var required_dungeons = schema.get("config_required_fields", {}).get("dungeons", [])
	var required_sets = schema.get("config_required_fields", {}).get("sets", [])

	# 检查 equipment.json
	var equipment = ConfigLoader.equipment_data.get("items", [])
	for item in equipment:
		_check_required_fields(item, required_all + required_equipment, "equipment")

	# 检查 affixes.json
	var affixes = ConfigLoader.affixes_data.get("affixes", [])
	for affix in affixes:
		_check_required_fields(affix, required_all + required_affixes, "affix")

	# 检查 skills.json
	var skills = ConfigLoader.skills_data.get("skills", [])
	for skill in skills:
		_check_required_fields(skill, required_all + required_skills, "skill")

	# 检查 enemies.json
	var enemies = ConfigLoader.enemies_data.get("enemies", [])
	for enemy in enemies:
		_check_required_fields(enemy, required_all + required_enemies, "enemy")

	# 检查 dungeons.json
	var dungeons = ConfigLoader.dungeons_data.get("dungeons", [])
	for dungeon in dungeons:
		_check_required_fields(dungeon, required_all + required_dungeons, "dungeon")

	# 检查 sets.json
	var sets = ConfigLoader.sets_data.get("sets", [])
	for set_item in sets:
		_check_required_fields(set_item, required_all + required_sets, "set")

	print("  装备: %d 条, 词缀: %d 条, 技能: %d 条, 敌人: %d 条, 副本: %d 条, 套装: %d 条" % [
		equipment.size(), affixes.size(), skills.size(), enemies.size(), dungeons.size(), sets.size()
	])

func _check_required_fields(item: Dictionary, required_fields: Array, type: String):
	var item_id = item.get("id", "未知")
	for field in required_fields:
		if not item.has(field):
			errors.append("%s[%s] 缺少必填字段: %s" % [type, item_id, field])

## 2. 检查重复 ID
func _validate_duplicate_ids():
	print("[检查] ID 唯一性...")

	var all_ids = {}

	# 收集所有配置的 ID
	_collect_ids(ConfigLoader.equipment_data.get("items", []), "equipment", all_ids)
	_collect_ids(ConfigLoader.affixes_data.get("affixes", []), "affixes", all_ids)
	_collect_ids(ConfigLoader.skills_data.get("skills", []), "skills", all_ids)
	_collect_ids(ConfigLoader.enemies_data.get("enemies", []), "enemies", all_ids)
	_collect_ids(ConfigLoader.dungeons_data.get("dungeons", []), "dungeons", all_ids)
	_collect_ids(ConfigLoader.classes_data.get("classes", []), "classes", all_ids)
	_collect_ids(ConfigLoader.sets_data.get("sets", []), "sets", all_ids)
	_collect_ids(ConfigLoader.waves_data.get("wave_sets", []), "wave_sets", all_ids)

	# 检查重复
	for id in all_ids.keys():
		var locations = all_ids[id]
		if locations.size() > 1:
			errors.append("重复 ID: %s 出现在 %s" % [id, ", ".join(locations)])

func _collect_ids(items: Array, source: String, id_map: Dictionary):
	for item in items:
		var id = item.get("id", "")
		if id != "":
			if not id_map.has(id):
				id_map[id] = []
			id_map[id].append(source)

## 3. 检查跨配置表的引用完整性
func _validate_cross_references():
	print("[检查] 引用完整性...")

	# 构建索引
	var affix_ids = _build_id_set(ConfigLoader.affixes_data.get("affixes", []))
	var class_ids = _build_id_set(ConfigLoader.classes_data.get("classes", []))
	var set_ids = _build_id_set(ConfigLoader.sets_data.get("sets", []))
	var wave_ids = _build_id_set(ConfigLoader.waves_data.get("wave_sets", []))
	var enemy_ids = _build_id_set(ConfigLoader.enemies_data.get("enemies", []))
	var skill_ids = _build_id_set(ConfigLoader.skills_data.get("skills", []))

	# equipment 引用的 affix_id 是否在 affixes 中存在
	for item in ConfigLoader.equipment_data.get("items", []):
		for affix_id in item.get("fixed_affixes", []):
			if not affix_ids.has(affix_id):
				errors.append("equipment[%s] 引用不存在的词缀: %s" % [item.get("id", "?"), affix_id])

		# equipment 引用的 set_id 是否在 sets 中存在
		var set_id = item.get("set_id", "")
		if set_id != "" and not set_ids.has(set_id):
			errors.append("equipment[%s] 引用不存在的套装: %s" % [item.get("id", "?"), set_id])

	# skills 引用的 class 是否在 classes 中存在
	for skill in ConfigLoader.skills_data.get("skills", []):
		var cls = skill.get("class", "")
		if cls != "all" and cls != "" and not class_ids.has(cls):
			errors.append("skill[%s] 引用不存在的职业: %s" % [skill.get("id", "?"), cls])

	# dungeons 引用的 wave_set 是否在 waves 中存在
	for dungeon in ConfigLoader.dungeons_data.get("dungeons", []):
		var ws = dungeon.get("wave_set", "")
		if ws != "" and not wave_ids.has(ws):
			errors.append("dungeon[%s] 引用不存在的波次: %s" % [dungeon.get("id", "?"), ws])

	# waves.spawns[].enemy 引用的敌人是否在 enemies 中存在
	for wave_set in ConfigLoader.waves_data.get("wave_sets", []):
		for wave in wave_set.get("waves", []):
			for spawn in wave.get("spawns", []):
				var enemy = spawn.get("enemy", "")
				if enemy != "" and not enemy_ids.has(enemy):
					errors.append("wave_set[%s] 引用不存在的敌人: %s" % [wave_set.get("id", "?"), enemy])

	# classes.skills[] 引用的技能是否在 skills 中存在
	for cls in ConfigLoader.classes_data.get("classes", []):
		for skill_id in cls.get("skills", []):
			if not skill_ids.has(skill_id):
				errors.append("class[%s] 引用不存在的技能: %s" % [cls.get("id", "?"), skill_id])

func _build_id_set(items: Array) -> Dictionary:
	var result = {}
	for item in items:
		var id = item.get("id", "")
		if id != "":
			result[id] = true
	return result

## 4. 检查数值合理性
func _validate_value_ranges():
	print("[检查] 数值合理性...")

	for item in ConfigLoader.equipment_data.get("items", []):
		var item_id = item.get("id", "?")
		var slot = item.get("slot", "")
		var stats = item.get("base_stats", {})

		# attack_speed 按部位区分语义：
		#   weapon: 倍率（0.5-3.0，1.0 = 标准）
		#   其它部位: 百分比加成（-0.3 到 0.5，0.1 = +10%）
		if stats.has("attack_speed"):
			var val = stats.attack_speed
			if slot == "weapon":
				if val < 0.5 or val > 3.0:
					warnings.append("equipment[%s] attack_speed=%s 武器倍率超出范围 (0.5-3.0)" % [item_id, val])
			else:
				if val < -0.3 or val > 0.5:
					warnings.append("equipment[%s] attack_speed=%s 非武器加成超出范围 (-0.3-0.5)" % [item_id, val])

		# crit_chance 应在 0-0.75
		if stats.has("crit_chance"):
			var val = stats.crit_chance
			if val < 0 or val > 0.75:
				warnings.append("equipment[%s] crit_chance=%s 超出合理范围 (0-0.75)" % [item_id, val])

		# crit_damage 是加成倍率（add_stat 类）：可以是 0.2 表示 +20% 暴伤，也可以是 1.5 表示总暴伤倍率
		# 当前装备语义是"加成"（叠加到 player.crit_damage 基础 1.5 上），合理范围 0-3.0
		if stats.has("crit_damage"):
			var val = stats.crit_damage
			if val < 0 or val > 3.0:
				warnings.append("equipment[%s] crit_damage=%s 超出合理范围 (0-3.0，加成语义)" % [item_id, val])

		# move_speed 是百分比加成：-0.5 到 1.0（0.1 = +10%）
		if stats.has("move_speed"):
			var val = stats.move_speed
			if val < -0.5 or val > 1.0:
				warnings.append("equipment[%s] move_speed=%s 超出合理范围 (-0.5-1.0)" % [item_id, val])

		# damage 应该 > 0
		if stats.has("damage"):
			var val = stats.damage
			if val <= 0:
				errors.append("equipment[%s] damage=%s 必须大于 0" % [item_id, val])

		# max_hp 应该 > 0
		if stats.has("max_hp"):
			var val = stats.max_hp
			if val <= 0:
				errors.append("equipment[%s] max_hp=%s 必须大于 0" % [item_id, val])

	# 检查敌人数值
	for enemy in ConfigLoader.enemies_data.get("enemies", []):
		var enemy_id = enemy.get("id", "?")
		var stats = enemy.get("base_stats", {})

		if stats.has("damage") and stats.damage <= 0:
			errors.append("enemy[%s] damage=%s 必须大于 0" % [enemy_id, stats.damage])

		if stats.has("max_hp") and stats.max_hp <= 0:
			errors.append("enemy[%s] max_hp=%s 必须大于 0" % [enemy_id, stats.max_hp])

## 5. 检查稀有度阶梯合理性
func _validate_rarity_progression():
	print("[检查] 稀有度阶梯...")

	var rarity_order = schema.get("rarity_levels", {}).get("order", ["common", "rare", "epic", "legendary", "mythic"])

	# 按 slot + drop_level 分组
	var groups = {}
	for item in ConfigLoader.equipment_data.get("items", []):
		var slot = item.get("slot", "")
		var drop_level = item.get("drop_level", 1)
		var rarity = item.get("rarity", "common")
		var key = "%s_lv%d" % [slot, drop_level]

		if not groups.has(key):
			groups[key] = {}

		if not groups[key].has(rarity):
			groups[key][rarity] = []

		groups[key][rarity].append(item)

	# 检查每组的稀有度阶梯
	for group_key in groups.keys():
		var group = groups[group_key]

		# 计算每个稀有度的综合战斗力（统一公式，覆盖所有部位）
		var rarity_avg_power = {}
		for rarity in rarity_order:
			if group.has(rarity):
				var total_power = 0.0
				var count = 0
				for item in group[rarity]:
					total_power += _equipment_power(item)
					count += 1
				if count > 0:
					rarity_avg_power[rarity] = total_power / count

		# 检查阶梯是否递增
		for i in range(1, rarity_order.size()):
			var lower_rarity = rarity_order[i - 1]
			var higher_rarity = rarity_order[i]

			if rarity_avg_power.has(lower_rarity) and rarity_avg_power.has(higher_rarity):
				var lower_power = rarity_avg_power[lower_rarity]
				var higher_power = rarity_avg_power[higher_rarity]

				# 允许 30% 偏差
				if higher_power < lower_power * 0.7:
					warnings.append("稀有度阶梯异常: %s 的 %s (%.1f) 明显弱于 %s (%.1f)" % [
						group_key, higher_rarity, higher_power, lower_rarity, lower_power
					])

## 综合战斗力评估（统一公式，覆盖所有部位）
## 把进攻、生存、增益都折算成一个可比数值，避免只看 damage+hp 误判防具/手套
func _equipment_power(item: Dictionary) -> float:
	var stats = item.get("base_stats", {})
	var slot = item.get("slot", "")
	var power := 0.0

	# 进攻
	power += stats.get("damage", 0.0)
	# 攻速：武器是倍率（1.2→+0.2），其它部位是百分比加成（0.1→+0.1），折算成 damage 当量
	if stats.has("attack_speed"):
		var asp = stats["attack_speed"]
		var bonus = (asp - 1.0) if slot == "weapon" else asp
		power += bonus * 40.0
	# 暴击：crit_chance + crit_damage 折算
	power += stats.get("crit_chance", 0.0) * 100.0
	power += stats.get("crit_damage", 0.0) * 20.0

	# 生存
	power += stats.get("max_hp", 0.0) * 0.1
	power += stats.get("armor", 0.0) * 0.5
	power += stats.get("hp_regen", 0.0) * 5.0

	# 机动
	power += stats.get("move_speed", 0.0) * 30.0

	# 词缀槽也是价值（每槽约等于一档稀有度）
	power += item.get("affix_slots", 0) * 8.0

	return power

## 6. Schema 白名单校验（PR-5 添加）
##    所有 rarity/slot/class 必须在 Schema 常量中；禁止旧的 uncommon、enhance_level 等
func _validate_schema_whitelist():
	# 装备 rarity / slot
	for item in ConfigLoader.get_all_equipment():
		var id = item.get("id", "?")
		var rarity = item.get("rarity", "")
		if rarity != "" and not Schema.is_valid_rarity(rarity):
			errors.append("[%s] rarity 非法: '%s' (合法: %s)" % [id, rarity, Schema.RARITIES])
		var slot = item.get("slot", "")
		if slot != "" and not Schema.is_valid_slot(slot):
			errors.append("[%s] slot 非法: '%s' (合法: %s)" % [id, slot, Schema.SLOTS])

	# 套装 rarity（可选字段，但若有必须合法）
	for s in ConfigLoader.get_all_sets():
		var rarity = s.get("rarity", "")
		if rarity != "" and not Schema.is_valid_rarity(rarity):
			errors.append("[set %s] rarity 非法: '%s'" % [s.get("id", "?"), rarity])

	# 技能 class 字段（"all" 或 Schema.CLASS_IDS 之一）
	for sk in ConfigLoader.get_all_skills():
		var cls = sk.get("class", "all")
		if cls != "all" and not Schema.is_valid_class(cls):
			errors.append("[skill %s] class 非法: '%s' (合法: %s 或 'all')" % [
				sk.get("id", "?"), cls, Schema.CLASS_IDS])

	# 副本 unlock.clear_<id> 引用必须存在
	for d in ConfigLoader.get_all_dungeons():
		var unlock = d.get("unlock", {})
		var prereq = unlock.get("clear_dungeon", "")
		if prereq != "" and ConfigLoader.get_dungeon_by_id(prereq).is_empty():
			errors.append("[dungeon %s] unlock.clear_dungeon 引用不存在的副本: '%s'" % [
				d.get("id", "?"), prereq])

	# balance.json class_mechanics 键名必须是去前缀的 6 个职业短名
	var mechanics = ConfigLoader.balance_data.get("class_mechanics", {})
	if mechanics is Dictionary:
		var allowed_short = Schema.CLASS_SHORT.values()
		for key in mechanics:
			if not (key in allowed_short) and key != "description" and key != "design_note":
				warnings.append("[balance.class_mechanics] 未知键: '%s' (合法: %s)" % [key, allowed_short])

	# 禁止 JSON 中出现旧字段名 enhance_level / 旧稀有度 uncommon
	var raw_balance = ConfigLoader.balance_data
	if _has_forbidden_token(raw_balance, "uncommon"):
		errors.append("[balance.json] 含旧稀有度名 'uncommon'，已废弃合并入 'rare'")
	for item in ConfigLoader.equipment_data.get("items", []):
		if item.has("enhance_level"):
			errors.append("[%s] 字段名错误: 'enhance_level' 应为 '%s'" % [
				item.get("id", "?"), Schema.K_ENHANCEMENT_LEVEL])

## 递归查找字典里是否含某个键名（用于检测旧字段残留）
func _has_forbidden_token(d, token: String) -> bool:
	if d is Dictionary:
		for k in d:
			if k == token:
				return true
			if _has_forbidden_token(d[k], token):
				return true
	elif d is Array:
		for v in d:
			if _has_forbidden_token(v, token):
				return true
	return false

## 加载 schema
func _load_schema() -> Dictionary:
	var path = "res://config/_schema_standard.json"
	if not ResourceLoader.exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		return {}
	return json.data

## 输出结果
func _print_results():
	print("\n========== 校验结果 ==========")
	print("❌ 错误: %d 个" % errors.size())
	print("⚠️  警告: %d 个" % warnings.size())

	if errors.size() > 0:
		print("\n错误详情:")
		for e in errors:
			print("  • %s" % e)

	if warnings.size() > 0:
		print("\n警告详情:")
		for w in warnings:
			print("  • %s" % w)

	if errors.size() == 0 and warnings.size() == 0:
		print("✅ 所有配置检查通过！")

	print("================================\n")
