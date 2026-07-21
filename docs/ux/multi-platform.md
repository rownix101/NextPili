# 多平台适配（Multi-platform / Adaptive）

> 状态：草案 v0.2  
> 依赖：[UX 索引](./README.md) · [设计规范](./design-system.md) · [交互](./interaction.md)  
> 参考：[Flutter Adaptive & Responsive](https://docs.flutter.dev/ui/adaptive-responsive) · [Material window size classes](https://m3.material.io/foundations/layout/applying-layout)

本文约定 **同一套 Flutter UI** 在 Linux / Windows / macOS，以及后续手机 / 平板 / 折叠屏上的布局、导航、输入、玻璃策略与系统集成。  
原则：**响应式布局 + 有限的平台差异化**，不做三套独立 UI；**Liquid Glass 只跟 chrome 走，不跟「是不是手机」走**。

---

## 1. 目标平台与优先级

| 优先级 | 平台 | 说明 |
|--------|------|------|
| P0 | Linux、Windows、macOS | 桌面端首发；窗口化、键盘、多显示器 |
| P1 | 平板（大屏 Android / iPadOS） | 布局复用 `medium` / `expanded`；壳层可玻璃 |
| P2 | 手机（竖屏） | 底栏导航、单列信息流；架构与 token 预留，功能可后于桌面 |
| P2 | 折叠屏 | **同一套断点**；外屏 ≈ compact，内屏 ≈ medium/expanded；铰链区不放关键控件 |

**非目标（首期交付）**：Web 发布、嵌入式、车机。  
**设计期已考虑**：手机 / 折叠的导航形态与玻璃边界（见 §12），避免日后推翻 chrome 结构。

---

## 2. 两个概念

| 概念 | 含义 | 手段 |
|------|------|------|
| **Responsive（响应式）** | 随窗口尺寸/方向改变布局 | 断点、弹性网格、`LayoutBuilder` |
| **Adaptive（自适应）** | 随平台能力/习惯改变行为 | 菜单栏、滚动条、文件对话框、快捷键修饰键 |

两者同时做：窗口从窄拉到宽要好看；在 macOS 上要像桌面应用而非手机模拟器。

---

## 3. 窗口尺寸与断点

### 3.1 尺寸档（逻辑像素宽度）

对齐 Material Window Size Class 思路，命名供文档与代码共用：

| 档位 | 宽度 | 典型形态 | 导航 | 内容 |
|------|------|----------|------|------|
| `compact` | < 600 | 窄窗、未来手机 | NavigationBar 或 Drawer | 单列 |
| `medium` | 600–839 | 小桌面窗、竖屏平板 | Rail（可收起）或 Drawer | 单列/双列 |
| `expanded` | 840–1199 | 笔记本默认 | NavigationRail | 多列网格；可双栏 |
| `large` | 1200–1599 | 外接显示器 | Rail + 可选双栏 | 网格 + 最大内容宽 |
| `extraLarge` | ≥ 1600 | 超宽 | Rail + 右栏详情可选 | 多列；播放器超宽舞台 |

高度：播放页在 **短高窗口**（如 < 500）时优先保证播放器，评论改折叠/路由。

### 3.2 断点使用规则

- 使用 **内容区宽度**（扣除 Rail）做网格列数计算，而非仅 `MediaQuery.size.width`（避免侧栏挤爆）。
- 断点切换时：
  - **保持**滚动位置与导航选中项；
  - 避免剧烈跳动；列数变化允许重排。
- 禁止按 `Platform.isWindows` 写死布局宽度；平台只影响 chrome 与输入。

### 3.3 网格列数（视频卡）

| 内容区宽 | 列数（建议） |
|----------|--------------|
| < 400 | 1 |
| 400–699 | 2 |
| 700–999 | 3 |
| 1000–1299 | 4 |
| ≥ 1300 | 5–6（封顶，避免卡片过小） |

卡片最小宽度约 **220–260**；用 `max(1, width ~/ minCardWidth)` 计算更稳。

---

## 4. 导航与壳层（Shell）

### 4.1 壳层变体

```text
compact:     [ AppBar + Body + NavigationBar ]
medium:      [ Rail(collapsed) + Body ] 或 Drawer
expanded+:   [ Rail + Body + (optional secondary) ]
```

- 一级目的地数量建议 **3–5**，过多收入「更多」。
- 设置页：桌面可用 **左侧设置分类 + 右侧表单**；compact 用推入式列表。

### 4.2 双栏（List–Detail）

适用：收藏夹内视频列表、消息（后续）、设置。

| 档位 | 行为 |
|------|------|
| compact | 只显示列表；点选 push 详情 |
| expanded+ | 左列表右详情；深链同时选中两侧 |

播放场景：**播放器 + 右侧相关/评论** 可作为 `large+` 增强，非必须。

### 4.3 多窗口（桌面增强）

| 能力 | 优先级 | 说明 |
|------|--------|------|
| 单主窗口 | P0 | 默认 |
| 弹出播放小窗 / 多窗口视频 | P1 | 依赖窗口插件与播放器架构 |
| 多实例进程 | 低 | 一般不需要 |

首期按 **单窗口多路由** 设计即可，API 预留「打开独立播放窗」的交互入口可隐藏。

---

## 5. 输入与设备

### 5.1 输入矩阵

| 输入 | 桌面 | 触控笔记本 | 手机（未来） |
|------|------|------------|--------------|
| 鼠标 | 主 | 主 | 少 |
| 键盘 | 主 | 主 | 少 |
| 触摸 | 可选 | 要支持 | 主 |
| 触控笔 | 忽略 | 可选 | 可选 |
| 触觉 / 震动 | 通常无；触控板有则可选 | 有则跟触摸策略 | 主增强通道 |

- 命中区域：桌面可略小于移动，但 **≥ 32px**。
- 同时存在指针与触摸时：hover 仅指针触发；点击共用。
- **触觉**：语义、开关与场景表见 [interaction.md §6.4](./interaction.md#64-触觉--震动反馈haptics)；无执行器时 no-op，**禁止**按平台在 feature 里复制业务逻辑。
- **图标标签**：展开导航 / 宽壳遵循 [design-system §7](./design-system.md#7-图标--已锁定)（标签始终可见）；`compact` 底栏允许 icon + 短标签；**禁止**无标签的一级导航。

### 5.2 修饰键

| 操作 | Windows/Linux | macOS |
|------|---------------|-------|
| 命令主修饰 | `Ctrl` | `Meta`（⌘） |
| 搜索 | `Ctrl+K` / `/` | `Meta+K` / `/` |
| 刷新 | `Ctrl+R` | `Meta+R` |
| 关闭页/返回 | `Alt+←` 或自定义 | `Meta+[` 等（对齐实现能力） |

快捷键文案展示必须 **按平台显示正确修饰符**（`ShortcutActivator` / 自定义 label）。

### 5.3 滚动

- 桌面：尊重系统滚动方向与平滑滚动设置。
- 列表使用物理滚动；长列表虚拟化（`ListView.builder` / 第三方）。
- 滚动条：桌面可始终可及或 hover 显示；移动端通常隐藏。
- **macOS**：优先使用平台滚动条观感（Flutter 平台自适应或主题配置）。

---

## 6. 平台差异化清单

### 6.1 必须适配（P0）

| 项 | 约定 |
|----|------|
| 窗口最小尺寸 | 建议 min ≈ 800×500（可配置）；低于此出现滚动而非挤爆 |
| 桌面穿透 | 透明窗口 + Liquid Glass chrome；内容不透明托盘（见 [design-system §2.2.1](./design-system.md#221-桌面穿透desktop-pierce)） |
| 标题栏 | 可用系统标题栏或沉浸式自定义；自定义时保留双击最大化、拖拽移动 |
| 文件/目录选择 | 使用系统对话框（缓存目录、下载路径） |
| 打开外链 | 系统默认浏览器 |
| 通知 | 可选；若做则走系统通知中心 |
| 路径与文件名 | 注意 Windows 分隔符与非法字符 |
| 托盘/后台 | 可选；关闭到托盘需设置项明确 |

### 6.2 建议适配（P1）

| 项 | 约定 |
|----|------|
| macOS 菜单栏 | 应用菜单：关于、设置、编辑、窗口、帮助 |
| Windows 跳转列表 | 可选 |
| 深链 URL Scheme | `nextpili://` 或 https 关联（后续） |
| 硬件加速 / HDR | 设置项与媒体层联动 |
| 多显示器全屏 | 全屏到当前窗所在屏 |

### 6.3 视觉与控件

- **统一 Liquid Glass chrome + Material 语义**；不在 macOS 整页换 Cupertino，也不在 Android 整页换另一套玻璃语言。
- 以下可平台微调：
  - 滚动条外观
  - 右键菜单与系统菜单快捷键文案
  - 字体回退（CJK）
  - 窗口阴影与圆角（**仅**随系统 / WM；应用壳层勿再叠窗缘圆角）
  - 玻璃质量上限（弱机 `minimal`，见 design-system §2.4–2.5）

---

## 7. 安全区与系统 UI

- 桌面一般无刘海；仍使用 `MediaQuery.padding` / `viewPadding` 处理：
  - 全屏播放时的显示器安全区；
  - 手机 notch、动态岛、底部 Home 指示条；
  - 折叠屏铰链附近的 `displayFeatures`（见 §12）。
- 全屏：隐藏应用壳层导航；退出全屏后完整恢复壳层状态。
- 底栏/顶栏必须坐在安全区之内。compact 底栏：**移动** = 悬浮 Liquid Glass；**桌面窄窗** = 贴边 Mica + icon/文字。Linux 桌面 blur 由**合成器**完成（勿 Flutter `BackdropFilter`）。内容可 `extendBody` 透到栏下，可点控件不得落入手势条/挖孔。

---

## 8. 播放器跨平台

| 关注点 | 约定 |
|--------|------|
| 内核 | 由媒体层选型（与 UX 无关），UI 只消费状态 |
| 全屏 API | `DesktopOsFullscreen` → `window_manager.setFullScreen`；UI 以 `PlayerSurfaceHost.fullscreen` 为源，系统退出全屏时 host 回 `inline` |
| 解码失败 | 引导检查系统解码器/关闭硬解（设置） |
| 高分屏 | 控件与字幕按逻辑像素；位图封面用合适分辨率缓存 |

---

## 9. 实现落点（Flutter）

与 [design/flutter.md](../design/flutter.md) 目录对齐：

```text
app/lib/core/adaptive/
  breakpoints.dart       # 档位枚举与计算
  window_size.dart       # WindowSizeClass
  desktop_window.dart    # 透明窗口 / desktopPierceEnabled
  shell.dart             # 响应式 Scaffold / Rail / Bar（features/shell）
  window_constraints.dart
  platform_shortcuts.dart
```

推荐模式：

- `LayoutBuilder` / `WindowSizeClass.of(context)` 自定义 Inherited。
- 功能页写 **内容**，壳层负责导航形态。
- 避免在业务页 `if (width > 800)` 散落；集中断点工具。

### 9.1 测试矩阵（立项验收向）

| 场景 | 检查 |
|------|------|
| 800×600 | 可用，无溢出 |
| 1280×720 | Rail + 3–4 列网格 |
| 1920×1080 | 多列 + 内容最大宽 |
| 超宽 2560+ | 不无限拉长文字行；播放器可拉满 |
| 缩放 125%/150% OS DPI | 布局不崩 |
| 键盘-only | 可完成搜索与播放 |
| 触控屏笔记本 | 列表与播放器可点 |

---

## 10. 与本地化的交叉

- 德语等长文案：按钮与 Rail 标签预留扩展（不要写死 4 个汉字宽）。
- RTL：Rail 边缘、返回手势、进度条方向见 [localization.md](./localization.md)。

---

## 11. 手机与折叠屏（P2 设计预留 · 实现可后置）

> 首发仍是桌面；本节约束 **壳层与玻璃**，避免手机版另起炉灶。功能 MVP 阶段仍按 architecture 的 P0–P6。

### 11.1 同一断点，不同输入

| 形态 | 宽度档 | 导航 | 玻璃 |
|------|--------|------|------|
| 手机竖屏 | `compact` | 悬浮 `GlassTabBar`（Liquid Glass）+ 顶栏 | 移动专用；桌面窄窗改用 Mica + icon/label |
| 手机横屏短高 | `compact` 或高度优先 | 播放优先；底栏可自动隐藏 | 播放中仅控件条 |
| 小平板 / 折叠内屏单栏 | `medium` | 收起 Rail 或双栏雏形 | 外壳玻璃，内容不透明 |
| 大平板 / 折叠内屏展开 | `expanded`+ | Rail 或 List–Detail | 同桌面中档 |
| 折叠外屏 | `compact`（通常更窄） | 同手机；信息密度更高 | 玻璃 **更克制**（见下） |

**禁止** `if (Platform.isAndroid) useGlass = false` 这种一刀切。  
应用 `WindowSizeClass` + 指针/触摸 + `GlassAdaptiveScope` 质量，而不是 OS 品牌。

### 11.2 折叠形态分类（都算折叠屏）

| 类型 | 典型机 | 铰链 | 外屏 / 封面 | 展开后 |
|------|--------|------|-------------|--------|
| **Fold（左右折 / 书本）** | Galaxy Z Fold、Pixel Fold | 竖缝 | 窄长条 ≈ 小手机 | 接近小平板，`medium`–`expanded` |
| **Flip（上下折 / 翻盖）** | Galaxy Z Flip、find N Flip | 横缝 | 小封面屏（cover） | 仍是手机宽，`compact`；可 **半开 Flex** |

二者 **共用** 断点与玻璃纪律，但 **壳层与播放布局不同**，禁止用「折叠」一词只覆盖 Fold。

数据源统一：

| API | 用途 |
|-----|------|
| `MediaQuery.size` / 自研 `WindowSizeClass` | 宽度档 → 导航形态 |
| `MediaQuery.displayFeatures` | 铰链矩形、挖孔；`DisplayFeatureType.hinge` / `fold` |
| 姿态（后续） | 半开角；无可靠 API 时用 hinge 把视口劈成上下/左右两区作启发式 |

**状态连续**：外屏/封面 ↔ 内屏/展开 ↔（Flip）半开，均须保留导航选中、列表锚点、播放进度；允许改布局，**禁止**重置路由栈或重开播放会话。

---

### 11.3 Fold（左右折）

铰链为 **竖直** 缝，适合 List–Detail。

| 议题 | 约定 |
|------|------|
| 外屏 | `compact`：同手机；玻璃仅顶/底；信息密度更高 |
| 内屏展开 | `medium` / `expanded`：Rail 或左列表右详情 |
| 双栏分缝 | **可对齐竖铰链**；主 CTA / 进度拖块 / 标题勿压在 hinge 带上 |
| 播放 | `large`：播放器 + 右侧评论/相关；铰链两侧内容完整可点 |
| 玻璃 | 外屏克制；内屏同桌面中档（外壳玻璃，Feed 不透明） |

```text
Fold 外屏 (compact)         Fold 内屏 (expanded)
┌─────────────┐            ┌──────┬──────────────────┐
│ GlassAppBar │            │Glass │ GlassAppBar      │
├─────────────┤            │Rail  ├──────────────────┤
│ 不透明 Feed │            │      │ 不透明 Feed│详情  │
├─────────────┤            │      │        ║铰链     │
│ GlassTab 浮 │            └──────┴──────────────────┘
└─────────────┘
```

---

### 11.4 Flip（上下折 / 翻盖）— 单独约定

铰链为 **水平** 缝；展开后宽度仍是手机，**不会** magically 变成平板。封面屏与半开是 Flip 特有路径。

#### 11.4.1 三种姿态

| 姿态 | 视口 | 产品能力（NextPili） | 玻璃 |
|------|------|----------------------|------|
| **合盖 · 封面屏（Cover）** | 极小（常见短列表级高度） | **P2 可选子集**，非完整 App | 默认 **不用** 折射玻璃 |
| **全开 · 主屏** | `compact` 手机 | 完整手机壳层（底栏 + 顶栏） | 同 §11.1 手机 |
| **半开 · Flex / 台式** | 上下两区被横铰链切开 | **播放优先** 布局（见下） | 上区画面零玻璃；下区控件可轻玻璃 |

```text
合盖封面              全开 compact           半开 Flex
┌──────────┐        ┌─────────────┐      ┌─────────────┐
│ 迷你信息  │        │ GlassAppBar │      │  播放器画面  │
│ 控件极少  │        ├─────────────┤      │  (上半 · 无玻璃)
└──────────┘        │ 不透明 Feed │      │════ 横铰链 ════│
                    ├─────────────┤      │ 控件 / 进度   │
                    │ GlassTab 浮 │      │ 评论摘要可选  │
                    └─────────────┘      │ (下半 · 可轻玻璃)
                                         └─────────────┘
```

#### 11.4.2 封面屏（Cover Display）能力边界

封面屏 **不是** 缩小版完整客户端。默认范围：

| 做（可选 P2+） | 不做（除非单独立项） |
|----------------|----------------------|
| 正在播放：标题、播/停、下一首/片 | 完整推荐 Feed / 多列网格 |
| 进度展示（粗）与锁屏式控制 | 复杂搜索、设置树、扫码登录主流程 |
| 私信/动态 **角标级** 提示（若做通知） | 长评论阅读与发送 |
| 一键「打开内屏继续」 | 玻璃导航壳、Tab 体系 |

封面策略：

- **不透明** 深色表面 + 大触控；`GlassQuality` 不适用或强制无 shader。
- 文案一行优先；禁止依赖 hover。
- 与内屏 **同一播放会话**（打开内屏接着播，不重载 playurl 除非必要）。

#### 11.4.3 半开 Flex（台式模式）

用户把 Flip **折成 L 形**（下半当底座、上半当屏幕）时：

| 规则 | 约定 |
|------|------|
| 识别 | `displayFeatures` 水平 hinge 将逻辑视口分为上下；或平台 posture API（有则优先） |
| 上半 | **只放播放器画面**（+ 可选极简手势：双击暂停）；无 AppBar、无 Feed |
| 下半 | 播放控件、清晰度/弹幕开关、可选相关列表/评论摘要；高度不够则只保留控件 |
| 铰链带 | 同 Fold：关键拖块与主按钮避开 hinge 像素带 |
| 旋转 | 半开时锁定或优先「铰链水平」方向，避免控件翻到上半 |
| 退出半开 | 回到全开 compact 壳层，**保留**播放进度与全屏前路由 |

Flex 是 **播放路径增强**，不是第三套信息架构：不从半开直接做完整五 Tab 导航。

#### 11.4.4 Flip 与玻璃（摘要）

| 姿态 | 玻璃 |
|------|------|
| 封面 | **无** Liquid Glass（可读 + 省电） |
| 全开 | 顶/底 chrome 可用 `standard`；Feed 不用 |
| 半开上半 | **无** |
| 半开下半 | 控件条可用 `glass.tint.player` 或轻 `minimal`/`standard`；不做大卡片玻璃墙 |

---

### 11.5 移动端何时用玻璃

与 [design-system §2.5](./design-system.md) 一致，并叠加折叠特判：

| 用 | 不用 |
|----|------|
| 底栏、顶栏、搜索 bar（手机 / Fold 外屏 / Flip 全开） | 双列/单列视频卡 |
| 评论发送栏（可选轻玻璃） | 每条评论气泡玻璃 |
| 清晰度/倍速菜单、ActionSheet | 播放器全屏起雾背景 |
| 迷你播放条；Flip 半开 **下半** 控件条 | 直播中大面积玻璃挡弹幕 |
| Fold 内屏 Rail / 顶栏 | **Flip 封面屏**；半开 **上半** 画面 |

触摸目标：移动 **≥ 48×48**；玻璃按钮的可点区域含透明边，禁止「视觉大、热区却只有图标」。

### 11.6 性能与电池（移动更严）

| 规则 | 说明 |
|------|------|
| 默认 `standard`，弱机 `minimal` | 依赖 `adaptiveQuality`；可设「省电模式」强制 minimal / 关折射 |
| 滚动列表 0 玻璃卡 | 硬规则，与桌面相同 |
| 播放中降载 | 全屏/半开上半可暂停非必要装饰动画；chrome 隐藏时不跑多余 shader |
| 封面屏 | 默认无自定义 shader；避免后台为外屏维持 premium 层 |
| 热节流 | 接受库自动降级；勿在业务里强行锁 `premium` |

### 11.7 实现落点补充

```text
app/lib/core/adaptive/
  breakpoints.dart
  shell.dart                 # compact 底栏 / expanded Rail
  display_features.dart      # 铰链安全区、Fold 竖缝双栏、Flip 横缝上下分带（P2）
  fold_posture.dart          # 可选：Fold vs Flip 启发式 + Flex 半开检测
  cover_shell.dart           # Flip 封面屏极简壳（P2+）
  glass_policy.dart          # size class + 姿态 + 省电 → 质量上限
```

| 模块 | 职责 |
|------|------|
| `display_features.dart` | 解析 hinge 方向（竖=Fold 双栏缝，横=Flip 上下分） |
| `fold_posture.dart` | `book` / `flip_open` / `flip_flex` / `cover` 枚举给 Shell |
| `cover_shell.dart` | 封面专用路由子集，不复用完整 `GlassScaffold` |

---

## 12. 验收清单（多平台）

- [ ] 断点切换无状态丢失
- [ ] compact / expanded 导航形态正确切换
- [ ] 修饰键文案按平台正确
- [ ] 最小窗口可用
- [ ] 全屏进出壳层状态正确
- [ ] 无 `Platform.isX` 滥用导致的布局分叉失控
- [ ] 信息流在任意形态下无玻璃卡片
- [ ] 手机安全区：底栏/顶栏控件不被 Home 条或刘海遮挡
- [ ] **Fold**：外屏↔内屏保留状态；竖铰链带无关键控件；双栏可对齐铰链
- [ ] **Flip 全开**：同手机壳层与玻璃纪律
- [ ] **Flip 半开**：上半仅画面、下半控件；横铰链避让；退出半开进度仍在
- [ ] **Flip 封面**（若实现）：无完整 Feed、无 Liquid Glass；与内屏同一播放会话
- [ ] 弱机或 Reduce Transparency 下核心路径仍可用
