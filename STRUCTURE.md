# 项目结构规范（STRUCTURE）

> 本文件定义 GameForge / DarkLoot 仓库的文件分类与归位规则。
> 目的：让每个文件都有明确的家，避免根目录堆积过程性产物。
> 新增文件前，先对照本表确定它该放哪里。

---

## 目录职责总览

| 目录 | 放什么 | 不放什么 |
|------|--------|----------|
| `/`（根目录） | 仓库级锚点：`README.md`、`STRUCTURE.md`、`constitution.md`、`AUTO_DECISION_RULES.md`、`.gitignore` | 交付报告、运行日志、临时验证文件 |
| `producer/` | 制作人协作文档：进度、待办、状态、决策、上手指南 | 一次性交付报告 |
| `project/` | 游戏项目本体 | 制作人流程文档 |
| `project/design/` | 设计文档：玩法、数值、世界观、内容规范 | 实现代码 |
| `project/src/` | **Godot 工程**（`res://` 根）。脚本/场景/配置/素材，路径不可随意移动 | 文档、工具脚本 |
| `roles/` | AI 角色定义（程序/美术/策划/测试等） | — |
| `specs/` | 配置表模板与编写指南（`*.tmpl.md`） | 实际配置数据（那些在 `project/src/config/`） |
| `tools/` | 构建/生成/校验脚本（`.py` / `.js` / `.sh` / `.bat`） | 脚本产出的报告 |
| `workflows/` | 工作流定义：内容生产、设计、实现、测试、发布 | — |

---

## Godot 工程内部（`project/src/`）

> ⚠️ 这些路径被 `project.godot` 和 `.tscn` 以 `res://` 引用，**移动会破坏工程**。只增不挪。

| 子目录 | 内容 |
|--------|------|
| `autoload/` | 全局单例系统（ConfigLoader、CombatSystem、RosterSystem 等） |
| `scripts/` | 节点挂载脚本（Player、Enemy、Town 等） |
| `scenes/` | 场景文件 `.tscn` 及其配套脚本 |
| `config/` | JSON 配置表（`_schema_standard.json` 为单一事实源） |
| `shaders/` | `.gdshader` |
| `tests/` | 单元测试与冒烟测试（`test_*.gd` / `smoke_*.gd`） |
| `assets/` | 美术、音频、生成资源 |

---

## 过程性产物：不入库

以下文件是构建/验证过程的副产物，**不提交**（已在 `.gitignore` 覆盖）：

- Godot 运行输出 / 验证日志：`*_verify.txt`、`verify_out.txt`、`godot_verify_full.txt`、`_v.txt`、`*.log`
- 临时文件：`*.tmp`
- 引擎缓存：`.godot/`
- 工作树：`.claude/worktrees/`

需要保留的验证结论，写进对应的 `producer/` 文档或测试用例，而不是留一个日志文件。

---

## 交付报告：写完即清

一次性的「完成报告 / 交付报告 / 构建报告」（如 `*_DELIVERY_REPORT.md`、`*_SUMMARY.md`、`RELEASE_REPORT.md`）：

- **不长期保留在根目录。**
- 有价值的结论应沉淀到 `producer/PROGRESS.md`、`producer/decisions.md` 或设计文档。
- 阶段结束后用 `git rm` 清理（参考历史提交 `2590093`、`2590093` 之后的清理批次）。

---

## 命名约定

- 文档：`UPPER_SNAKE.md`（仓库级锚点）或 `kebab-case.md`（设计/工作流文档）
- 测试：`test_<system>.gd`、`smoke_<scope>.gd`
- 配置模板：`<topic>-config.tmpl.md`
- 工具脚本：`gen_*.py`（生成）、`build_*.py`（构建）、`*_sim.*`（模拟）
