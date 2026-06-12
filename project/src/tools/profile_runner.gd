extends SceneTree
## 性能基准采样工具
## ============================================================
## 用法（headless）：
##   "$GODOT" --headless --path project/src -s res://tools/profile_runner.gd
##
## 输出：performance_report.json + 控制台摘要
##
## 测量场景：
##   1. 冷启动（autoload 初始化、配置加载）
##   2. 装备生成压测（连续生成 1000 件随机装备）
##   3. 标签联动重算压测（200 次 recompute_tags）
##   4. 配置访问吞吐（10000 次 ConfigLoader.get_all_*）
##   5. 内存基线（autoload + 配置加载完成后的对象/资源数）
##
## 不依赖游戏运行时（不开主场景、不实例化敌人），只压系统层。
## 这样能在 headless 下稳定测量「系统调用 + 数据访问 + 内存」三类成本。

const REPORT_PATH := "res://performance_report.json"

var _t0_ms: int = 0
var report: Dictionary = {}


func _initialize() -> void:
	print("\n========== Profiling 基准采样开始 ==========")
	_t0_ms = Time.get_ticks_msec()

	# 等待 autoload 全部 ready
	await process_frame
	await process_frame

	report["meta"] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"godot_version": Engine.get_version_info(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
	}
	report["startup"] = {
		"cold_start_ms": Time.get_ticks_msec() - _t0_ms,
	}
	print("[1/5] 冷启动: %d ms" % report["startup"]["cold_start_ms"])

	_bench_equipment_generation()
	_bench_tag_recompute()
	_bench_config_access()
	_capture_memory_baseline()

	_save_report()
	_print_summary()
	quit(0)


# ----------------------------------------------------------------
# 装备生成压测（核心战斗循环最热的路径之一：掉落->生成实例）
# ----------------------------------------------------------------
func _bench_equipment_generation() -> void:
	var es := root.get_node_or_null("EquipmentSystem")
	var cfg := root.get_node_or_null("ConfigLoader")
	if es == null or cfg == null:
		report["equipment_gen"] = {"skipped": "missing autoload"}
		return
	if not es.has_method("roll_equipment"):
		report["equipment_gen"] = {"skipped": "no roll_equipment method"}
		return

	var items: Array = cfg.get_all_equipment()
	if items.is_empty():
		report["equipment_gen"] = {"skipped": "no equipment data"}
		return

	const N := 1000
	var rarities := ["common", "rare", "epic", "legendary"]
	var t0 := Time.get_ticks_usec()
	for i in range(N):
		var base = items[i % items.size()]
		var rarity = rarities[i % rarities.size()]
		es.roll_equipment(base.get("id", ""), rarity)
	var dt_us := Time.get_ticks_usec() - t0

	report["equipment_gen"] = {
		"count": N,
		"total_us": dt_us,
		"avg_us_per_item": float(dt_us) / N,
		"items_per_sec": int(N * 1_000_000.0 / max(dt_us, 1)),
	}
	print(
		(
			"[2/5] 装备生成 x%d: %.2f ms (%.1f us/件, %d/秒)"
			% [
				N,
				dt_us / 1000.0,
				report["equipment_gen"]["avg_us_per_item"],
				report["equipment_gen"]["items_per_sec"]
			]
		)
	)


# ----------------------------------------------------------------
# 标签联动重算（每次穿戴/卸下装备都会触发，是 UI 卡顿嫌疑点）
# ----------------------------------------------------------------
func _bench_tag_recompute() -> void:
	var ts := root.get_node_or_null("TagSynergySystem")
	if ts == null or not ts.has_method("recompute_tags"):
		report["tag_recompute"] = {"skipped": "missing"}
		return

	const N := 200
	var t0 := Time.get_ticks_usec()
	for i in range(N):
		ts.recompute_tags()
	var dt_us := Time.get_ticks_usec() - t0
	report["tag_recompute"] = {
		"count": N,
		"total_us": dt_us,
		"avg_us": float(dt_us) / N,
	}
	print(
		(
			"[3/5] 标签重算 x%d: %.2f ms (%.1f us/次)"
			% [N, dt_us / 1000.0, report["tag_recompute"]["avg_us"]]
		)
	)


# ----------------------------------------------------------------
# 配置访问吞吐（autoload getter 是否被滥用？）
# ----------------------------------------------------------------
func _bench_config_access() -> void:
	var cfg := root.get_node_or_null("ConfigLoader")
	if cfg == null:
		report["config_access"] = {"skipped": "missing"}
		return

	const N := 10000
	var t0 := Time.get_ticks_usec()
	for i in range(N):
		# 抓住引用避免被优化掉，用变量名 sink_* 表示丢弃
		var sink_eq = cfg.get_all_equipment()
		var sink_af = cfg.get_all_affixes()
		var sink_sk = cfg.get_all_skills()
		# 防止 GDScript 警告 unused
		if false and sink_eq and sink_af and sink_sk:
			pass
	var dt_us := Time.get_ticks_usec() - t0
	report["config_access"] = {
		"count": N,
		"total_us": dt_us,
		"avg_us_per_call": float(dt_us) / (N * 3),
		"note": "每轮调 3 个 get_all_*，总调用数 = count*3",
	}
	print(
		(
			"[4/5] 配置访问 x%d (3-tuple): %.2f ms (%.2f us/调用)"
			% [N, dt_us / 1000.0, report["config_access"]["avg_us_per_call"]]
		)
	)


# ----------------------------------------------------------------
# 内存基线（对象数 / 资源数 / 节点数）
# ----------------------------------------------------------------
func _capture_memory_baseline() -> void:
	report["memory"] = {
		"static_mem_bytes": OS.get_static_memory_usage(),
		"static_mem_peak_bytes": OS.get_static_memory_peak_usage(),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
	}
	var mb: float = report["memory"]["static_mem_bytes"] / 1024.0 / 1024.0
	var peak_mb: float = report["memory"]["static_mem_peak_bytes"] / 1024.0 / 1024.0
	print(
		(
			"[5/5] 内存基线: %.1f MB (峰值 %.1f MB)，对象 %d，节点 %d (孤儿 %d)，资源 %d"
			% [
				mb,
				peak_mb,
				report["memory"]["object_count"],
				report["memory"]["node_count"],
				report["memory"]["orphan_node_count"],
				report["memory"]["resource_count"],
			]
		)
	)


# ----------------------------------------------------------------
# 输出
# ----------------------------------------------------------------
func _save_report() -> void:
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("无法写入报告: %s" % REPORT_PATH)
		return
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("\n[报告] 已保存: %s" % REPORT_PATH)


func _print_summary() -> void:
	print("\n========== 摘要 ==========")
	print("渲染器: %s" % report["meta"]["renderer"])
	print("冷启动: %d ms" % report["startup"]["cold_start_ms"])
	if report["equipment_gen"].has("avg_us_per_item"):
		print("装备生成: %.1f us/件" % report["equipment_gen"]["avg_us_per_item"])
	if report["tag_recompute"].has("avg_us"):
		print("标签重算: %.1f us/次" % report["tag_recompute"]["avg_us"])
	if report["config_access"].has("avg_us_per_call"):
		print("配置访问: %.2f us/调用" % report["config_access"]["avg_us_per_call"])
	print("内存峰值: %.1f MB" % (report["memory"]["static_mem_peak_bytes"] / 1024.0 / 1024.0))
	print("==========================\n")
