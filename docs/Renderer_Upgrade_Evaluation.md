# 渲染器升级评估报告

## 现状
- **当前渲染器**：`gl_compatibility`（OpenGL 2.0+ / GLES 2.0）
- **配置位置**：[project/src/project.godot](../project/src/project.godot) `[rendering]` 段

```ini
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

## 三档渲染器对比

| 项目 | gl_compatibility（当前） | mobile | forward_plus |
|------|---|---|---|
| **API 要求** | OpenGL 2.0+ / GLES 2 | Vulkan / GLES 3 | Vulkan only |
| **2D 动态光照（PointLight2D）** | ❌ 不支持 | ✅ 支持 | ✅ 支持 |
| **法线贴图（normal_map）** | ⚠️ 部分支持 | ✅ 完整支持 | ✅ 完整支持 |
| **混合模式** | 受限 | 完整 | 完整 |
| **着色器复杂度** | 受限 | 中 | 完整 |
| **GPU 兼容性** | 老电脑/手机/嵌入 | 主流 PC + 现代手机 | 仅现代 PC |
| **手机性能** | ✅ 最优 | ✅ 良好 | ⚠️ 偏重 |

## 升级到 mobile 的收益与代价

### 收益
1. **动态光照** — 火把/技能闪光/Boss 光环可以真正照亮场景
2. **法线贴图渲染** — 我们已生成的 18 张敌人 sprite 法线贴图能见效（立体感）
3. **更好的混合/光晕** — 稀有度发光、暴击粒子可做更复杂的视觉
4. **shader 自由度** — 现有 5 个 shader（dissolve/hit_flash/rarity_outline/status_overlay/vignette）可加更多效果

### 代价
1. **兼容性收窄** — Intel HD Graphics 4xxx 以前的老 GPU 无法运行（约影响 5-10% 远古机器）
2. **手机端必须支持 Vulkan / GLES 3**（2018 年后大部分手机都支持）
3. **shader 需要重新编译**，首次启动可能多 1-2 秒
4. **可能暴露隐性兼容问题** — 个别 .gdshader 在新渲染器下需调整

## 建议升级时机

**现在不建议升级。理由：**
- 当前游戏视觉风格偏向卡通像素，动态光照不是核心卖点
- 还在快速迭代期，渲染器切换会引入不确定的兼容问题
- 法线贴图管线已就绪（[gen_normal_maps.py](../tools/gen_normal_maps.py)），需要时再生效

**建议升级时机：**
- 进入「视觉打磨」阶段（玩法基本定型）
- 决定主推 PC 平台（手机老机型放弃）
- 有玩家明确反馈视觉表现力不足

## 一键升级/回滚

切换到 mobile 渲染器（解锁动态光照）：
```bash
python tools/switch_renderer.py mobile
```

回滚到 gl_compatibility（兼容性最广）：
```bash
python tools/switch_renderer.py gl_compatibility
```

切换后 Godot 首次启动会重新编译 shader（1-2 秒）。

## 渲染器升级后的额外工作

如果决定升级，还需做：
1. **测试现有 5 个 shader** 在新渲染器下是否正常
2. **批量生成法线贴图**（已有工具，跑一次即可）：
   ```bash
   python tools/gen_normal_maps.py
   ```
3. **挑选关键场景接入 PointLight2D**（如火把、Boss 光环）
4. **更新 README** 说明最低显卡要求

## 当前渲染相关资产清单

- 5 个 shader：[project/src/shaders/](../project/src/shaders/)
  - dissolve.gdshader（死亡溶解）
  - hit_flash.gdshader（受击闪白）
  - rarity_outline.gdshader（稀有度描边）
  - status_overlay.gdshader（状态层）
  - vignette.gdshader（暗角）
- 18 张敌人法线贴图（已生成，gitignored）
- 1 个全局 Theme：[project/src/theme/darkloot.tres](../project/src/theme/darkloot.tres)
