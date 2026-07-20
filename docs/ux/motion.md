# 动效设计（Motion）

> 状态：草案 v0.1  
> 依赖：[UX 索引](./README.md) · [设计规范](./design-system.md) · [交互](./interaction.md)  
> 参考：[Material 3 Motion](https://m3.material.io/styles/motion) · Flutter `Curves` / `Animated*` / `Hero` · `liquid_glass_widgets` Liquid Morph（菜单等）
本文定义动效原则、时长与缓动 token、典型场景编排。动效服务于 **空间感、状态变化可感知、操作反馈**，不为装饰而动。

---

## 1. 原则

1. **有目的**：每次动画回答「从哪来、到哪去、完成了什么」。
2. **快而清晰**：桌面 UI 偏短；宁短勿拖（尤其列表与 hover）。
3. **可打断**：用户快速连续操作时，动画可被新状态取消/替换，不排队卡顿。
4. **可关闭**：尊重系统「减少动态效果」；关闭后用瞬时切换或淡入淡出 0–100ms 级。
5. **性能优先**：60fps 为目标；避免同时大量模糊、大面积阴影动画、整表重建动画。
6. **一致性**：同类组件共用 token，禁止魔法数字散落。

---

## 2. 时长 Token

命名以语义为主，实现映射到毫秒。

| Token | 时长 | 适用 |
|-------|------|------|
| `duration.instant` | 0–50ms | 减少动效模式；开关瞬时态 |
| `duration.short1` | 50ms | 极微反馈（按压 opacity） |
| `duration.short2` | 100ms | 图标切换、小控件 |
| `duration.short3` | 150ms | 按钮、ripple 感知强化 |
| `duration.medium1` | 200ms | 默认 UI；fade；控件显隐 |
| `duration.medium2` | 250ms | 标准过渡 |
| `duration.medium3` | 300ms | 卡片展开、中等面板 |
| `duration.long1` | 400ms | 复杂布局切换、侧栏 |
| `duration.long2` | 500ms | 全屏进入/退出（可含系统） |
| `duration.long3` | 600ms | 极少；引导或庆祝类（首期基本不用） |
| `duration.playerChrome` | 200ms | 播放器控件淡入淡出 |
| `duration.playerChromeDelay` | 2500–3000ms | 无操作后隐藏控件的等待 |

**桌面建议**：常规界面过渡落在 **150–250ms**；超过 400ms 需有充分理由。

---

## 3. 缓动 Token（Easing）

采用 Material 3 常用强调曲线族（实现可用 `Cubic` 近似或 Flutter 预置 `Curves`）。

| Token | 语义 | 典型曲线（描述） | 使用 |
|-------|------|------------------|------|
| `easing.linear` | 线性 | 匀速 | 进度条确定进度、缓冲条 |
| `easing.standard` | 标准 | 缓入缓出 | 大多数属性变化 |
| `easing.standardDecelerate` | 减速进入 | 快出慢停 | **元素进入**屏幕 |
| `easing.standardAccelerate` | 加速离开 | 慢出快离 | **元素离开**屏幕 |
| `easing.emphasized` | 强调 | 更戏剧的标准曲线 | 重要容器变形、FAB 类（少用） |
| `easing.emphasizedDecelerate` | 强调进入 | | 大面板滑入 |
| `easing.emphasizedAccelerate` | 强调离开 | | 大面板滑出 |

Flutter 粗映射（实现可微调）：

| Token | Flutter 参考 |
|-------|----------------|
| standard | `Curves.easeInOutCubic` |
| decelerate 进入 | `Curves.easeOutCubic` |
| accelerate 离开 | `Curves.easeInCubic` |
| emphasized | `Curves.easeInOutCubicEmphasized`（若版本可用）或自定义 Cubic |

---

## 4. 运动模式

### 4.1 Fade（淡入淡出）

- 用途：Toast、播放器 chrome、图标状态、交叉淡化封面。
- 默认：`duration.medium1` + `easing.standard`。

### 4.2 Fade through

- 用途：同级 Tab 内容切换（推荐 ↔ 热门）。
- 旧内容加速淡出，新内容减速淡入；可轻微缩放 **0.96 → 1.0**（可选，减少动效时去掉缩放）。

### 4.3 Shared axis

- 用途：导航层级前进/后退（X 或 Z 轴）。
- 前进：新页自右侧/前方进入；后退对称。
- 桌面侧栏内 push：**水平 shared axis** 短距（8–16px 位移 + fade），避免移动端那种整屏大滑动喧宾夺主。

### 4.4 Container transform

- 用途：视频卡 → 播放详情（可选 Hero 封面）。
- 要求：
  - 封面 `Hero` tag 稳定（bvid）；
  - 中断时（快速返回）不残影；
  - 列表复用注意 tag 唯一。
- 首期若成本高：**可降级**为 fade through，不阻塞功能。

### 4.5 微交互

| 场景 | 动效 |
|------|------|
| 按钮按压 | 缩放 0.98 或 ink ripple；`short2–short3` |
| 图标切换（播/停） | 交叉淡入或 Morph；`short2` |
| 点赞 | 短暂 scale bounce（幅度小）；减少动效时仅变色 |
| 列表项插入/删除 | 高度动画 + fade；虚拟列表中慎用，优先瞬时 |
| 骨架屏 → 内容 | 内容 fade in，骨架 fade out；`medium1` |

---

## 5. 场景编排

### 5.1 路由转场

| 场景 | 方案 |
|------|------|
| 一级导航切换 | Fade through；**保持**各自滚动位置 |
| 列表 → 详情 | Fade through 或 Container transform |
| 详情 → 全屏播放（若分页） | Fade + 系统全屏；控件 `playerChrome` |
| 模态对话框 | 缩放自 0.9–1.0 + fade；scrim fade；`medium2` |
| 侧栏抽屉 | 边缘滑入 + scrim；`medium3` / `long1` |
| 菜单 / 弹出 | 锚点缩放 + fade；`short3`–`medium1` |

### 5.2 播放器

| 场景 | 方案 |
|------|------|
| Chrome 显示 | Fade in `duration.playerChrome` |
| Chrome 隐藏 | Fade out 同时长；**拖拽进度/菜单打开时不隐藏** |
| 进入全屏 | 优先系统动画；应用内控件延迟一帧再布局，避免闪烁 |
| 清晰度切换 | 可选短暂中心 loading；成功后轻 Toast，无整页转场 |
| 弹幕出现 | 线性位移（弹幕引擎），不走 Material 曲线；性能关键路径 |

### 5.3 反馈

| 场景 | 方案 |
|------|------|
| Snackbar | 自底部/下缘 slide + fade；可堆叠策略：替换前一条 |
| 拉取刷新 | 平台默认指示器；完成时短 fade |
| 进度不确定 | 线性/环形 indeterminate；避免无意义循环装饰动画 |

---

## 6. 与「减少动态效果」

当检测到系统 reduce motion（Flutter：`MediaQuery.disableAnimations` / 无障碍设置）：

| 原动效 | 降级 |
|--------|------|
| 位移、缩放、shared axis | 改为短 fade 或瞬时切换 |
| Hero 变形 | 关闭，直接切换 |
| 点赞 bounce | 仅颜色状态 |
| 播放器 chrome | 可瞬时显示/隐藏或保留极短 fade（≤100ms） |
| 弹幕 | **不关闭**（属内容），但用户可自行关弹幕 |

---

## 7. 实现约定（Flutter）

与 [design/flutter.md](../design/flutter.md) 目录对齐：

```text
app/lib/core/motion/
  durations.dart    # 时长常量
  easings.dart      # Curve 常量
  transitions.dart  # PageRoute 封装
```

- 禁止业务代码写 `Duration(milliseconds: 237)` 魔法数；引用 token。
- 自定义 `PageRouteBuilder` 统一封装，便于全局改转场。
- 动画控制器在 `dispose` 释放；列表 item 动画注意复用与暂停（离屏）。
- 优先组合：`AnimatedSwitcher`、`AnimatedOpacity`、`Hero`、隐式动画；复杂手势用显式 `AnimationController`。

### 7.1 性能预算

- 同时进行的重型动画（模糊、大图缩放）不超过 **1–2** 路。
- 滚动中：暂停非关键装饰动画。
- 低端设备：可探测并降级（后续）。

---

## 8. 验收清单（动效）

- [ ] 同类转场时长一致
- [ ] 快速连点无动画队列卡顿
- [ ] reduce motion 下可完成全部任务
- [ ] 播放器 chrome 显隐不抖动、不挡拖拽
- [ ] 无「为动而动」的无限循环装饰（除加载指示）
