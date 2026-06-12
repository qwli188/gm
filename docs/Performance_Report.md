# 性能优化清单与基线报告

> 生成时间：2026/06/11  
> 渲染器：mobile（Vulkan）  
> 测试基线：356/356 全绿

## 📊 当前性能基线

| 指标 | 数值 | 评估 |
|---|---|---|
| 冷启动 | 286 ms | ✅ 优秀 |
| 装备生成 | 37.8 us/件（26456/秒） | ✅ 优秀（修复前 14968 us/件，提速 555 倍） |
| 标签重算 | 5.5 us/次 | ✅ 优秀 |
| 配置访问 | 6.89 us/调用 | ✅ 优秀 |
| 内存峰值 | 26.7 MB | ✅ 优秀（autoload + 配置全加载） |

数据由 `tools/run_profile.py` 自动采集，存入 `tools/perf_baseline.json`。

## ✅ 已修复的性能问题

### 1. 装备生成热路径 print（**主热点**，提速 555 倍）
**位置**：[autoload/EquipmentSystem.gd](../project/src/autoload/EquipmentSystem.gd)  
**症状**：`roll_equipment` 内 `print()` 输出装备信息  
**影响**：每件装备 15 ms → 战斗中刷怪掉装备会卡帧  
**修复**：把 5 处热路径 print 改为 `print_verbose`（Godot 内置，仅 `--verbose` 启动时输出）  
**结果**：14968 us/件 → 27 us/件（提速 555 倍），66/秒 → 37049/秒

### 2. 其他热路径 print（连带修复）
- [autoload/TagSynergySystem.gd](../project/src/autoload/TagSynergySystem.gd):56,59 — 每次装备变更打 2 行
- [autoload/AffixWorkshop.gd](../project/src/autoload/AffixWorkshop.gd):68,107,366,431 — reforge/dismantle/upgrade/sanctify 每次都打
- [autoload/Inventory.gd](../project/src/autoload/Inventory.gd):60,75,89 — 背包满/仓库满/取回失败

共 **9 处 print** 改为 `print_verbose`，热路径零开销。

### 3. EquipmentSystem 加 DEBUG_LOG 开关
保留生成实例的详细日志（最有价值），用 `const DEBUG_LOG := false` 包起来。需要追踪问题时改一行即可打开。

## 🔧 工具链

| 工具 | 用途 | 命令 |
|---|---|---|
| `tools/profile_runner.gd` | Headless 性能采样器 | （由 Python 包装调用） |
| `tools/run_profile.py` | 一键运行 + 友好摘要 | `python tools/run_profile.py` |
| `--baseline` | 保存当前为基线 | `python tools/run_profile.py --baseline` |
| `--compare` | 与基线对比（性能回归检测） | `python tools/run_profile.py --compare` |

`tools/perf_baseline.json` 入库，作为团队约定的性能门槛。

## 🎯 待优化（按优先级）

### P1：实战场景压测（当前 profiler 只测系统层）
**问题**：当前 profiler 不测主场景（实例化敌人、刷波次、技能释放）  
**收益**：找到真正的运行时瓶颈  
**做法**：扩展 profile_runner.gd 支持「模拟主场景 5 秒」，统计 fps/draw call/物理步进  
**工作量**：1-2 小时

### P2：Sprite 图集打包
**问题**：216 张原图各自一个 draw call，敌人多时 GPU 提交开销大  
**收益**：合批后 draw call 可降 80%+  
**做法**：用 Godot 的 AtlasTexture 或 free-tex-packer-cli 打包  
**工作量**：2-3 小时（需调整 SpriteLibrary 加载路径）

### P3：autoload 间事件总线全量迁移
**问题**：当前只迁移了 1 个订阅方到 EventBus（TagSynergySystem）  
**收益**：解耦 + 更清晰的事件流（debug 时能看到所有事件）  
**做法**：把 HUD/各 Panel 等 UI 节点的订阅迁移到 EventBus  
**工作量**：3-4 小时

### P4：物理查询优化
**问题**：未压测，但 Enemy.gd 的视野检测每帧 raycast 是嫌疑点  
**收益**：未知（需 P1 实战压测后才能定量）  
**做法**：查询缓存 / 降低 _process 频率 / 用 Area2D 代替 raycast  
**工作量**：看 P1 结果定

### P5：内存对象监控 CI 接入
**问题**：当前手动跑 profiler，没有自动回归  
**收益**：性能下降立即报警  
**做法**：CI 跑 profiler，与 perf_baseline.json 对比，劣化 >20% 失败  
**工作量**：1 小时（GitHub Actions）

## 📋 性能回归操作手册

### 怀疑性能问题时
```bash
# 1. 跑当前性能
python tools/run_profile.py

# 2. 与基线对比
python tools/run_profile.py --compare
```

输出会显示每项指标的 +/- 百分比，>5% 偏差有箭头标记。

### 优化完成后更新基线
```bash
# 确认优化后效果好，更新基线
python tools/run_profile.py --baseline
git add tools/perf_baseline.json
git commit -m "perf: 更新基线 - <说明优化项>"
```

### Verbose 模式追问题
```bash
# 启用 print_verbose 输出（看装备/词缀工坊详情）
"$GODOT" --verbose --headless --path project/src -s res://tools/profile_runner.gd
```

或临时开 `EquipmentSystem.gd` 顶部的 `DEBUG_LOG := true`。
