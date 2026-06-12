extends CharacterBody2D
## 探索玩家 - 用于主城/领地/野外等非战斗场景
##
## 职责：纯移动 + 朝向 + 触发交互。不含任何战斗逻辑（攻击/受击/技能/敌人）。
## 输入：WASD 移动；左键点击地面也可寻路移动（点到该位置）；
##       靠近 InteractZone 时左键/E 触发交互（由场景脚本接管 InteractZone.interacted 信号）。
## 战斗 Player(Player.gd, 678行) 不在这里复用——保持探索逻辑轻量独立。

signal moved(pos: Vector2)

@export var move_speed: float = 320.0

var anim_sprite: AnimatedSprite2D = null
var _facing_left: bool = false
# 左键点地寻路目标（为空表示无）
var _click_target = null
const CLICK_ARRIVE_DIST := 12.0


func _ready():
	add_to_group("explorer")
	_setup_visual()


## 用当前操控角色的职业动画精灵（与战斗 Player 同源）
func _setup_visual():
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "Sprite"
	anim_sprite.scale = Vector2(2.6, 2.6)
	add_child(anim_sprite)
	ShaderHelper.ensure_drop_shadow(self, 44.0, 16.0, 30.0)

	var class_id = "class_warrior"
	if has_node("/root/GameState"):
		var cls = get_node("/root/GameState").get_current_class()
		class_id = cls.get("id", "class_warrior")
	anim_sprite.sprite_frames = SpriteLibrary.get_class_frames(class_id)
	anim_sprite.animation = "idle"
	anim_sprite.play("idle")


func _physics_process(_delta):
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir != Vector2.ZERO:
		# WASD 输入优先，取消点地寻路
		_click_target = null
		velocity = input_dir.normalized() * move_speed
	elif _click_target != null:
		# 左键点地寻路：朝目标直线移动，到达即停
		var to_target = _click_target - global_position
		if to_target.length() <= CLICK_ARRIVE_DIST:
			_click_target = null
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_facing(velocity)
	if velocity != Vector2.ZERO:
		moved.emit(global_position)


## 朝向与行走/待机动画
func _update_facing(vel: Vector2):
	if anim_sprite == null:
		return
	if abs(vel.x) > 1.0:
		_facing_left = vel.x < 0
		anim_sprite.flip_h = _facing_left
	if vel.length() > 1.0:
		if anim_sprite.animation != "walk" and anim_sprite.sprite_frames.has_animation("walk"):
			anim_sprite.play("walk")
	else:
		if anim_sprite.animation != "idle" and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")


## 场景脚本调用：设置左键点地的寻路目标
func set_click_target(world_pos: Vector2):
	_click_target = world_pos
