extends Node
## AudioManager - 游戏音效管理器（全局单例）
## 统一管理所有音效的播放，通过 play(name) 调用

const SFX_DIR = "res://assets/audio/sfx/"

# 音效映射表：语义名称 → 文件
const SFX_MAP = {
	"attack":    "attack.ogg",
	"hit":       "hit.ogg",
	"hit_crit":  "hit.ogg",
	"coin":      "coin.ogg",
	"item_drop": "item_drop.ogg",
	"equip":     "equip.ogg",
	"level_up":  "level_up.ogg",
	"ui_click":  "ui_click.ogg",
	"footstep":  "footstep00.ogg",
}

# 预加载音频池（每种 3 个播放器，避免同帧重叠音被截断）
var _pools: Dictionary = {}

func _ready():
	print("[AudioManager] 音效系统初始化")
	for key in SFX_MAP:
		var path = SFX_DIR + SFX_MAP[key]
		var stream = load(path) as AudioStream
		if stream == null:
			push_warning("[AudioManager] 找不到音效: %s" % path)
			continue
		var pool = []
		for i in range(3):
			var player = AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = -6.0
			add_child(player)
			pool.append(player)
		_pools[key] = pool

## 播放音效。name 对应 SFX_MAP 的键
func play(name: String, volume_db: float = 0.0):
	if not _pools.has(name):
		return
	var pool = _pools[name]
	# 找到一个没在播放的播放器
	for player in pool:
		if not player.playing:
			player.volume_db = -6.0 + volume_db
			player.play()
			return
	# 全在播放就抢第一个
	pool[0].play()
