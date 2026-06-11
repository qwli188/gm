extends Node
## FeedbackSystem - P8 手感反馈集中管理
##
## 职责：
## - hitstop / 屏幕震动：从 CombatSystem 抽出，提供更可调的统一接口
## - 累计伤害飘字：同一目标 0.3s 内的多次伤害合并显示，避免数字洪流
## - 拾取过滤：按稀有度阈值决定是否在地图显示装备牌（玩家可调）
## - 击杀慢镜头：Boss 死亡时 0.4 秒慢动作

# ============ 拾取过滤（持久于 GameState 之外，UI 偏好）============
# 0=显示全部 1=rare+ 2=epic+ 3=legendary+ 4=mythic only
const FILTER_ALL := 0
const FILTER_RARE := 1
const FILTER_EPIC := 2
const FILTER_LEGENDARY := 3
const FILTER_MYTHIC := 4

var loot_filter_threshold: int = FILTER_ALL

# ============ 累计伤害飘字 ============
# 每个目标的最近一次飘字状态：{target_id: {acc_amount, last_time, last_node}}
var _damage_accum: Dictionary = {}
const ACCUM_WINDOW := 0.30  # 0.3 秒内的命中合并
const ACCUM_LEAK_INTERVAL := 1.5  # 表清理间隔

var _leak_timer: float = 0.0

# ============ 屏幕震动状态 ============
var _shake_remaining: float = 0.0
var _shake_intensity: float = 0.0
var _shake_camera = null

# ============ Hitstop 状态 ============
var _hitstop_active: bool = false

func _ready():
	print("[FeedbackSystem] 反馈系统初始化")
	process_mode = PROCESS_MODE_ALWAYS  # 即使在暂停时也跑（hitstop 用 time_scale 而非 paused）

func _process(delta: float):
	# 累计表清理
	_leak_timer += delta
	if _leak_timer > ACCUM_LEAK_INTERVAL:
		_leak_timer = 0.0
		_prune_accum()
	# 震动衰减
	if _shake_remaining > 0.0 and _shake_camera and is_instance_valid(_shake_camera):
		_shake_remaining -= delta
		var t = max(0.0, _shake_remaining / 0.15)
		var amp = _shake_intensity * t
		_shake_camera.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		if _shake_remaining <= 0.0:
			_shake_camera.offset = Vector2.ZERO
			_shake_camera = null

# ============ Hitstop ============
## 顿帧（短暂 time_scale=0），duration 单位秒。同一帧多次调用以最长者为准。
func hitstop(duration: float):
	if duration <= 0:
		return
	if _hitstop_active:
		return  # 简化：忽略嵌套，避免被 0 的 time_scale 反复重置
	_hitstop_active = true
	Engine.time_scale = 0.0
	# 用真实时间不受 time_scale 影响
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
		_hitstop_active = false
	)

# ============ 屏幕震动 ============
## intensity 是像素幅度。同一帧多次调用以最大者为准。
func shake(intensity: float, duration: float = 0.15):
	if intensity <= 0 or duration <= 0:
		return
	var tree = get_tree()
	if tree == null:
		return
	var camera = tree.get_root().get_viewport().get_camera_2d()
	if camera == null:
		return
	# 已在震动：延长 + 取较大幅度
	if intensity > _shake_intensity:
		_shake_intensity = intensity
	if duration > _shake_remaining:
		_shake_remaining = duration
	_shake_camera = camera

# ============ 击杀慢镜头（用于 Boss 死亡）============
func slowmo(scale: float = 0.35, duration: float = 0.4):
	Engine.time_scale = clamp(scale, 0.05, 1.0)
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

# ============ 累计伤害飘字 ============
## 优先调用此方法替代 DamageNumber.spawn：同一 target 0.3s 内的伤害会合并到上次的飘字上。
## target: 目标节点（用 instance_id 做 key）
## parent: 飘字挂载父节点（一般是 target.get_parent()）
## pos: 显示位置（target.global_position + 偏移）
## amount: 本次伤害
## is_crit: 是否暴击
func damage_text(target: Node, parent: Node, pos: Vector2, amount: float, is_crit: bool = false):
	var key = "" if target == null else str(target.get_instance_id())
	var now = Time.get_ticks_msec() / 1000.0
	if key != "" and _damage_accum.has(key):
		var prev = _damage_accum[key]
		if now - float(prev.get("last_time", 0)) < ACCUM_WINDOW and is_instance_valid(prev.get("last_node")):
			# 累计到上一条飘字
			prev["acc_amount"] = float(prev["acc_amount"]) + amount
			prev["last_time"] = now
			var node = prev["last_node"]
			if node.has_method("update_amount"):
				node.update_amount(prev["acc_amount"], is_crit or prev.get("was_crit", false))
				prev["was_crit"] = is_crit or prev.get("was_crit", false)
				_damage_accum[key] = prev
				return
	# 新建飘字
	DamageNumber.spawn(parent, pos, amount, is_crit)
	# 找到刚生成的节点（最后一个加入的子节点）
	var spawned = parent.get_children().back() if parent.get_child_count() > 0 else null
	_damage_accum[key] = {
		"acc_amount": amount,
		"last_time": now,
		"last_node": spawned,
		"was_crit": is_crit,
	}

func _prune_accum():
	var now = Time.get_ticks_msec() / 1000.0
	var to_remove = []
	for k in _damage_accum:
		var entry = _damage_accum[k]
		if now - float(entry.get("last_time", 0)) > ACCUM_WINDOW * 4:
			to_remove.append(k)
		elif not is_instance_valid(entry.get("last_node")):
			to_remove.append(k)
	for k in to_remove:
		_damage_accum.erase(k)

# ============ 拾取过滤 ============
const RARITY_RANK := {
	"common": 0, "rare": 1, "epic": 2, "legendary": 3, "mythic": 4
}

func set_loot_filter(threshold: int):
	loot_filter_threshold = clamp(threshold, FILTER_ALL, FILTER_MYTHIC)
	print("[FeedbackSystem] 拾取过滤阈值: %d" % loot_filter_threshold)

## 是否应该在地图上显示该装备牌（按稀有度阈值）
func should_display_drop(rarity: String) -> bool:
	return RARITY_RANK.get(rarity, 0) >= loot_filter_threshold

func filter_label() -> String:
	match loot_filter_threshold:
		FILTER_ALL: return "全部显示"
		FILTER_RARE: return "稀有及以上"
		FILTER_EPIC: return "史诗及以上"
		FILTER_LEGENDARY: return "传奇及以上"
		FILTER_MYTHIC: return "仅神话"
		_: return "?"
