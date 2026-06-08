extends CanvasLayer

@onready var player = get_node("/root/Main/Player")

# 属性显示与加点
@onready var strength_label = $Panel/Content/Left/Attributes/Strength/Value
@onready var agility_label = $Panel/Content/Left/Attributes/Agility/Value
@onready var vitality_label = $Panel/Content/Left/Attributes/Vitality/Value
@onready var intelligence_label = $Panel/Content/Left/Attributes/Intelligence/Value
@onready var points_label = $Panel/Content/Left/PointsLabel

@onready var str_btn = $Panel/Content/Left/Attributes/Strength/AddBtn
@onready var agi_btn = $Panel/Content/Left/Attributes/Agility/AddBtn
@onready var vit_btn = $Panel/Content/Left/Attributes/Vitality/AddBtn
@onready var int_btn = $Panel/Content/Left/Attributes/Intelligence/AddBtn

# 装备槽位（8个部位）
@onready var equipment_slots = {
	"weapon": $Panel/Content/Middle/EquipmentGrid/WeaponSlot,
	"helmet": $Panel/Content/Middle/EquipmentGrid/HelmetSlot,
	"chest": $Panel/Content/Middle/EquipmentGrid/ChestSlot,
	"legs": $Panel/Content/Middle/EquipmentGrid/LegsSlot,
	"gloves": $Panel/Content/Middle/EquipmentGrid/GlovesSlot,
	"boots": $Panel/Content/Middle/EquipmentGrid/BootsSlot,
	"amulet": $Panel/Content/Middle/EquipmentGrid/AmuletSlot,
	"ring": $Panel/Content/Middle/EquipmentGrid/RingSlot,
}

# 统计面板
@onready var stats_display = $Panel/Content/Right/Stats

func _ready():
	visible = false

	# 连接按钮
	str_btn.pressed.connect(_on_add_strength)
	agi_btn.pressed.connect(_on_add_agility)
	vit_btn.pressed.connect(_on_add_vitality)
	int_btn.pressed.connect(_on_add_intelligence)

	$Panel/Content/Right/Buttons/SkillTreeBtn.pressed.connect(_on_skill_tree_pressed)
	$Panel/Content/Right/Buttons/InventoryBtn.pressed.connect(_on_inventory_pressed)
	$Panel/Content/Right/Buttons/CloseBtn.pressed.connect(_on_close_pressed)

	# 监听玩家属性变化
	if player:
		player.attributes_changed.connect(_refresh_attributes)
		player.attribute_points_changed.connect(_refresh_points)
		player.stats_recalculated.connect(_refresh_stats)

func _input(event):
	if event.is_action_pressed("toggle_character_panel"):
		toggle_panel()

func toggle_panel():
	visible = !visible
	if visible:
		_refresh_all()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _refresh_all():
	_refresh_attributes(player.attributes)
	_refresh_points(player.attribute_points_unspent)
	_refresh_equipment()
	_refresh_stats()

func _refresh_attributes(attrs: Dictionary):
	strength_label.text = str(attrs.get("strength", 0))
	agility_label.text = str(attrs.get("agility", 0))
	vitality_label.text = str(attrs.get("vitality", 0))
	intelligence_label.text = str(attrs.get("intelligence", 0))

func _refresh_points(unspent: int):
	points_label.text = "剩余点数: %d" % unspent
	# 根据剩余点数启用/禁用按钮
	var has_points = unspent > 0
	str_btn.disabled = !has_points
	agi_btn.disabled = !has_points
	vit_btn.disabled = !has_points
	int_btn.disabled = !has_points

func _refresh_equipment():
	if not has_node("/root/EquipmentSystem"):
		return
	var eq_sys = get_node("/root/EquipmentSystem")
	var equipped = eq_sys.get_equipped_items()

	# 清空槽位显示
	for slot_name in equipment_slots:
		var slot = equipment_slots[slot_name]
		slot.text = ""

	# 填充已装备物品
	for slot_name in equipped:
		var item = equipped[slot_name]
		if equipment_slots.has(slot_name):
			var slot = equipment_slots[slot_name]
			slot.text = item.get("display_name", slot_name)
			# 可扩展：显示图标、颜色按稀有度等

func _refresh_stats():
	if not player:
		return

	var stats_text = """当前属性:
生命: %.0f / %.0f
伤害: %.1f
攻速: %.2f
暴击率: %.1f%%
暴击伤害: %.1fx
护甲: %.1f
移速: %.0f""" % [
		player.current_hp, player.max_hp,
		player.damage,
		player.attack_speed,
		player.crit_chance * 100,
		player.crit_damage,
		player.armor,
		player.move_speed
	]

	stats_display.text = stats_text

func _on_add_strength():
	player.add_attribute("strength", 1)

func _on_add_agility():
	player.add_attribute("agility", 1)

func _on_add_vitality():
	player.add_attribute("vitality", 1)

func _on_add_intelligence():
	player.add_attribute("intelligence", 1)

func _on_skill_tree_pressed():
	print("[CharacterPanel] 技能树功能待实现")
	# TODO: 打开技能树面板

func _on_inventory_pressed():
	print("[CharacterPanel] 背包功能待实现")
	# TODO: 打开背包面板

func _on_close_pressed():
	toggle_panel()



