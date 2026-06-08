extends Node
## 词缀系统 - 管理装备词缀效果
## 这是"装备构筑深度"的引擎：词缀之间的化学反应

# 当前生效的词缀效果列表
var active_affixes: Array = []

func _ready():
	print("[AffixSystem] 词缀系统初始化")

## 应用词缀效果
func apply_affix_effect(affix_data: Dictionary):
	active_affixes.append(affix_data)

	var effect = affix_data.get("effect", {})
	var kind = effect.get("kind", "")

	match kind:
		"add_stat":
			_apply_add_stat(effect)
		"mult_stat":
			_apply_mult_stat(effect)
		"lifesteal":
			_apply_lifesteal(effect)
		"ignite":
			_apply_ignite(effect)
		_:
			push_warning("[AffixSystem] 未实现的词缀效果类型: %s" % kind)

## 属性平加（如 +10 伤害）
func _apply_add_stat(effect: Dictionary):
	var stat = effect.get("stat", "")
	var value = effect.get("value", 0)
	print("[AffixSystem] 应用属性加成: %s +%s" % [stat, value])
	# 注：属性加成通过EquipmentSystem统计，玩家recalculate_stats时应用

## 属性百分比增益（如 +15% 攻速）
func _apply_mult_stat(effect: Dictionary):
	var stat = effect.get("stat", "")
	var value = effect.get("value", 0.0)
	print("[AffixSystem] 应用属性增益: %s +%d%%" % [stat, value * 100])
	# 注：属性增益通过EquipmentSystem统计，玩家recalculate_stats时应用

## 吸血效果
func _apply_lifesteal(effect: Dictionary):
	var value = effect.get("value", 0.0)
	print("[AffixSystem] 应用吸血: %d%%" % (value * 100))
	# 注：吸血效果在CombatSystem.apply_damage中触发

## 点燃效果
func _apply_ignite(effect: Dictionary):
	var dps = effect.get("dps", 0)
	var duration = effect.get("duration", 0)
	print("[AffixSystem] 应用点燃: %d DPS 持续 %d 秒" % [dps, duration])
	# 注：点燃效果在CombatSystem.apply_damage中触发

## 检查是否有指定标签的词缀
func has_tag(tag: String) -> bool:
	for affix in active_affixes:
		var tags = affix.get("tags", [])
		if tag in tags:
			return true
	return false

## 计算指定标签的词缀数量（用于套装效果）
func count_tag(tag: String) -> int:
	var count = 0
	for affix in active_affixes:
		var tags = affix.get("tags", [])
		if tag in tags:
			count += 1
	return count

## 清空所有词缀（卸下装备时调用）
func clear_all_affixes():
	active_affixes.clear()
	print("[AffixSystem] 清空所有词缀")
