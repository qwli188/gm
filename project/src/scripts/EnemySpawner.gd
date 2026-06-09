extends Node2D
## 敌人生成器 - 读取 waves.json 按时间波次生成敌人
## 配置表驱动：波次曲线全部来自配置

signal boss_spawned(boss_node)
signal wave_advanced(wave_index)

var current_waveset_id: String = "waveset_crypt"
var difficulty_mult_hp: float = 1.0
var difficulty_mult_dmg: float = 1.0

var elapsed_time: float = 0.0
var wave_data: Array = []
var spawn_accumulators: Dictionary = {}
var burst_fired: Dictionary = {}
var current_enemy_count: int = 0
var max_total_enemies: int = 60

func _ready():
	add_to_group("enemy_spawner")
	# 从 GameState 读取选中的副本配置
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		current_waveset_id = gs.selected_waveset
		difficulty_mult_hp = gs.selected_hp_mult
		difficulty_mult_dmg = gs.selected_dmg_mult
	_load_waveset()

func _load_waveset():
	var waves_data = ConfigLoader.waves_data.get("wave_sets", [])
	for ws in waves_data:
		if ws.get("id", "") == current_waveset_id:
			wave_data = ws.get("waves", [])
			print("[EnemySpawner] 加载波次组: %s (%d 波段)" % [current_waveset_id, wave_data.size()])
			return
	push_warning("[EnemySpawner] 未找到波次组: %s" % current_waveset_id)

## 设置副本（GameManager 进副本时调用）
func setup_dungeon(waveset_id: String, hp_mult: float, dmg_mult: float):
	current_waveset_id = waveset_id
	difficulty_mult_hp = hp_mult
	difficulty_mult_dmg = dmg_mult
	elapsed_time = 0.0
	burst_fired = {}
	spawn_accumulators = {}
	_load_waveset()

func _process(delta):
	elapsed_time += delta
	_process_waves(delta)

func _process_waves(delta):
	for i in range(wave_data.size()):
		var wave = wave_data[i]
		var start = wave.get("start_time", 0)
		var end = wave.get("end_time", 999999)
		if elapsed_time < start or elapsed_time >= end:
			continue

		var spawns = wave.get("spawns", [])
		for j in range(spawns.size()):
			var spawn = spawns[j]
			var enemy_id = spawn.get("enemy_id", "")

			# burst：一次性生成
			if spawn.get("burst", false):
				var burst_key = "%d_%d" % [i, j]
				if not burst_fired.has(burst_key):
					burst_fired[burst_key] = true
					for k in range(spawn.get("count", 1)):
						var spawned = _spawn_enemy(enemy_id)
						if spawned and (enemy_id.begins_with("boss_") or enemy_id.begins_with("field_boss_")):
							boss_spawned.emit(spawned)
				continue

			# rate：按速率持续生成
			var rate = spawn.get("rate", 0.0)
			if rate <= 0:
				continue
			var acc_key = "%d_%d" % [i, j]
			spawn_accumulators[acc_key] = spawn_accumulators.get(acc_key, 0.0) + rate * delta
			while spawn_accumulators[acc_key] >= 1.0:
				spawn_accumulators[acc_key] -= 1.0
				if current_enemy_count < max_total_enemies:
					_spawn_enemy(enemy_id)

func _spawn_enemy(enemy_id: String):
	var enemy = load("res://scripts/Enemy.gd").create_enemy(enemy_id, _get_spawn_position())
	if enemy == null:
		return null
	if enemy.has_method("apply_difficulty"):
		enemy.apply_difficulty(difficulty_mult_hp, difficulty_mult_dmg)
	get_parent().add_child(enemy)
	enemy.tree_exited.connect(_on_enemy_removed)
	current_enemy_count += 1
	return enemy

func _on_enemy_removed():
	current_enemy_count -= 1

func _get_spawn_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	var center = player.global_position if player else global_position
	var angle = randf() * TAU
	return center + Vector2(cos(angle), sin(angle)) * 700.0
