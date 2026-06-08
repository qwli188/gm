extends Node2D
class_name EffectSprite
## 一次性特效播放器 - 播放 SpriteLibrary 的特效帧后自动销毁
## 用法: EffectSprite.spawn(parent, "fire", global_pos, scale)

static func spawn(parent: Node, kind: String, pos: Vector2, scale_factor: float = 1.0, fps: float = 14.0) -> void:
	var frames: Array = SpriteLibrary.get_effect_frames(kind)
	if frames.is_empty():
		return
	var node := Node2D.new()
	node.set_script(load("res://scripts/EffectSprite.gd"))
	node.global_position = pos
	node.scale = Vector2(scale_factor, scale_factor)
	parent.add_child(node)
	node._play(frames, fps)

var _sprite: Sprite2D
var _frames: Array = []
var _index: int = 0
var _timer: float = 0.0
var _frame_time: float = 0.07

func _play(frames: Array, fps: float) -> void:
	_frames = frames
	_frame_time = 1.0 / fps
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	add_child(_sprite)

func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_timer += delta
	if _timer >= _frame_time:
		_timer -= _frame_time
		_index += 1
		if _index >= _frames.size():
			queue_free()
			return
		_sprite.texture = _frames[_index]
