extends Node
## 美术层测试 - A1 配色收口 / A2 区域主题 / A3 元素配色与特效安全性

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("art: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))

# ============ A1: 配色单一真源 ============
func test_schema_is_single_source():
	# Schema 是真源，其余系统必须返回相同色值
	for r in Schema.RARITIES:
		var schema_c = Schema.rarity_color(r)
		var eq_c = EquipmentSystem.get_rarity_color(r)
		var rv_c = RarityVisuals.get_rarity_color(r)
		var ph_c = ParticleHelper._get_rarity_color(r)
		_check("color match Eq[%s]" % r, schema_c == eq_c, "%s vs %s" % [schema_c, eq_c])
		_check("color match RV[%s]" % r, schema_c == rv_c, "")
		_check("color match PH[%s]" % r, schema_c == ph_c, "")

func test_schema_rank_ordering():
	_check("rank: common < mythic", Schema.rarity_rank("common") < Schema.rarity_rank("mythic"), "")
	_check("rank: legendary=3", Schema.rarity_rank("legendary") == 3, "got " + str(Schema.rarity_rank("legendary")))
	_check("rank: unknown=-1", Schema.rarity_rank("garbage") == -1, "")

func test_schema_derived_visuals():
	# 暗色应比基色暗，发光应比基色亮
	var base = Schema.rarity_color("epic")
	var dark = Schema.rarity_dark_color("epic")
	var glow = Schema.rarity_glow_color("epic")
	_check("derived: dark < base value", dark.v < base.v, "")
	_check("derived: glow >= base value", glow.v >= base.v, "")
	# 边框宽度递增
	_check("derived: mythic border > common", Schema.rarity_border_width("mythic") > Schema.rarity_border_width("common"), "")

func test_rarity_visuals_stylebox():
	# 边框样式应能生成且颜色匹配
	var style = RarityVisuals.get_rarity_border_style("legendary")
	_check("stylebox: created", style != null, "")
	_check("stylebox: border color matches schema", style.border_color == Schema.rarity_color("legendary"), "")

# ============ A2: 区域主题 ============
func test_region_accent():
	_check("region: crypt accent defined", ThemeGenerator.get_region_accent("crypt") != ThemeGenerator.COLOR_ACCENT, "")
	_check("region: unknown falls back to accent", ThemeGenerator.get_region_accent("nonexistent") == ThemeGenerator.COLOR_ACCENT, "")
	# 6 区域都有
	for region in ["crypt", "swamp", "forge", "ice", "void", "field"]:
		_check("region: %s has accent" % region, ThemeGenerator.REGION_ACCENT.has(region), "")
		_check("region: %s has vignette" % region, ThemeGenerator.REGION_VIGNETTE.has(region), "")

func test_system_panel_factory():
	var parts = ThemeGenerator.create_system_panel("测试面板")
	_check("panel: root is PanelContainer", parts["root"] is PanelContainer, "")
	_check("panel: has title", parts["title"] is Label, "")
	_check("panel: has body", parts["body"] is VBoxContainer, "")
	_check("panel: title text set", parts["title"].text == "测试面板", "")
	# 清理
	parts["root"].queue_free()

func test_rarity_panel_factory():
	var panel = ThemeGenerator.create_rarity_panel("mythic")
	_check("rarity panel: created", panel is Panel, "")
	panel.queue_free()

# ============ A3: 元素配色 ============
func test_element_colors():
	_check("element: fire defined", ParticleHelper.element_color("fire") != Color.WHITE, "")
	_check("element: fire==ignite", ParticleHelper.element_color("fire") == ParticleHelper.element_color("ignite"), "")
	_check("element: ice==freeze", ParticleHelper.element_color("ice") == ParticleHelper.element_color("freeze"), "")
	_check("element: unknown is white", ParticleHelper.element_color("unknown_elem") == Color.WHITE, "")

func test_effects_no_crash_without_parent():
	# 传 null parent 不应崩溃（防御性）
	ParticleHelper.spawn_slash_trail(null, Vector2.ZERO, Vector2.RIGHT)
	ParticleHelper.spawn_dash_afterimage(null, Vector2.ZERO)
	var dur = ParticleHelper.spawn_boss_entrance(null, Vector2.ZERO)
	_check("effects: null-safe slash/afterimage/boss", dur == 0.0, "boss entrance returns 0 on null")

func test_effects_spawn_with_parent():
	# 真实 parent 下生成节点不崩溃
	var holder = Node2D.new()
	add_child(holder)
	ParticleHelper.spawn_slash_trail(holder, Vector2(100, 100), Vector2.RIGHT, 70.0, ParticleHelper.element_color("fire"))
	ParticleHelper.spawn_dash_afterimage(holder, Vector2(100, 100))
	ParticleHelper.spawn_skill_burst(holder, Vector2(100, 100), "ice")
	var dur = ParticleHelper.spawn_boss_entrance(holder, Vector2(200, 200))
	_check("effects: boss entrance returns positive dur", dur > 0.0, "got " + str(dur))
	_check("effects: children spawned", holder.get_child_count() > 0, "got " + str(holder.get_child_count()))
	holder.queue_free()

# ============ A4: 落地阴影 + 描边收口 ============
func test_drop_shadow_idempotent():
	var owner = Node2D.new()
	add_child(owner)
	ShaderHelper.ensure_drop_shadow(owner, 40, 14, 28)
	_check("shadow: created", owner.has_node("DropShadow"), "")
	# 再次调用应幂等（不重复添加）
	ShaderHelper.ensure_drop_shadow(owner, 40, 14, 28)
	var count = 0
	for c in owner.get_children():
		if c.name == "DropShadow":
			count += 1
	_check("shadow: idempotent (only 1)", count == 1, "got " + str(count))
	# 阴影在脚下（z_index 负，置于角色后）
	var sh = owner.get_node("DropShadow")
	_check("shadow: z_index negative", sh.z_index < 0, "")
	owner.queue_free()

func test_drop_shadow_null_safe():
	ShaderHelper.ensure_drop_shadow(null)
	_check("shadow: null-safe", true, "")

func test_rarity_glow_uses_schema():
	# apply_rarity_glow 现在用 Schema 色，验证 material 的 outline_color 与 Schema 一致
	var node = Sprite2D.new()
	add_child(node)
	ShaderHelper.apply_rarity_glow(node, "legendary")
	_check("glow: material set", node.material != null, "")
	if node.material:
		var oc = node.material.get_shader_parameter("outline_color")
		_check("glow: outline color == schema legendary", oc == Schema.rarity_color("legendary"), "got " + str(oc))
	node.queue_free()

func run_tests() -> Dictionary:
	test_schema_is_single_source()
	test_schema_rank_ordering()
	test_schema_derived_visuals()
	test_rarity_visuals_stylebox()
	test_region_accent()
	test_system_panel_factory()
	test_rarity_panel_factory()
	test_element_colors()
	test_effects_no_crash_without_parent()
	test_effects_spawn_with_parent()
	test_drop_shadow_idempotent()
	test_drop_shadow_null_safe()
	test_rarity_glow_uses_schema()

	print("\n--- 美术层测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
