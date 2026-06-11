extends Node
## 配置文件监听器 - 自动检测 config/*.json 变化并触发热重载
## 仅在编辑器模式下激活（OS.is_debug_build()）

var _file_mtimes: Dictionary = {}
var _check_interval: float = 1.0
var _timer: float = 0.0
var _enabled: bool = false

const CONFIG_FILES = [
	"equipment.json",
	"affixes.json",
	"skills.json",
	"enemies.json",
	"classes.json",
	"dungeons.json",
	"waves.json",
	"sets.json",
	"balance.json",
	"vfx.json"
]


func _ready() -> void:
	_enabled = OS.is_debug_build()
	if not _enabled:
		print("[FileWatcher] 非调试模式，文件监听已禁用")
		return
	_initialize_mtimes()
	print("[FileWatcher] 配置文件监听已启动")


func _process(delta: float) -> void:
	if not _enabled:
		return
	_timer += delta
	if _timer >= _check_interval:
		_timer = 0.0
		_check_files()


func _initialize_mtimes() -> void:
	for fname in CONFIG_FILES:
		var path = "res://config/" + fname
		var mtime = _get_mtime(path)
		if mtime > 0:
			_file_mtimes[fname] = mtime


func _check_files() -> void:
	for fname in CONFIG_FILES:
		var path = "res://config/" + fname
		var current_mtime = _get_mtime(path)
		var last_mtime = _file_mtimes.get(fname, 0)
		if current_mtime > 0 and current_mtime != last_mtime:
			_file_mtimes[fname] = current_mtime
			if last_mtime > 0:
				print("[FileWatcher] 检测到变化: " + fname)
				ConfigLoader.reload_config(fname)


func _get_mtime(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_modified_time(path)
