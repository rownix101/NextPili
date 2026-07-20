# 设计规范（Design System）

> 状态：草案 v0.5.1  
> 依赖：[UX 索引](./README.md) · [动效](./motion.md) · [多平台](./multi-platform.md) · [交互](./interaction.md) · [文案](./copy.md)  
> 视觉语言：**Liquid Glass**（iOS 26 气质，桌面适配）  
> 实现库：[liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets) `^0.22.1`  
> UI 底座：**自有语义 Token** + Flutter `ThemeData` / `ThemeExtension`（**不采用 Material 3 视觉语言**）  
> 图标：**Lucide** · 字体：**Inter** + 系统 CJK  
> 参考：[NN/g Icon Usability](https://www.nngroup.com/articles/icon-usability/) · [Apple HIG · Buttons / Icons](https://developer.apple.com/design/human-interface-guidelines/icons) · WCAG 1.1.1 / 4.1.2

本文定义 NextPili 的视觉语言、配色、字体、图标、材质 token 与组件约定。  
**玻璃用于导航与控制层；内容区保持不透明、可读。**

---

## 1. 设计目标

| 目标 | 说明 |
|------|------|
| 统一 | 全平台一套 token；禁止业务页硬编码色值 / 模糊半径 |
| 可主题化 | 浅色 / 深色 / 跟随系统；种子强调色可配置 |
| 内容优先 | 视频封面、标题、进度与弹幕是主角；玻璃只服务 chrome |
| 桌面效率 | 密度可调、键盘可达、GPU 预算可控（玻璃质量分级） |
| 可访问 | 对比度、焦点环、Reduce Motion / Reduce Transparency 默认尊重 |

设计原则一句话：**内容不透明、chrome 可玻璃、暗色电影感、强调色克制。**

---

## 2. 视觉语言：Liquid Glass

### 2.1 语言定义

NextPili 采用 **Liquid Glass** 作为主导视觉语言：

- 半透明折射表面 + 高光边缘 + 柔和景深
- 材质「像液体玻璃」：有厚度、高光、轻微色散，而不是扁平 `opacity + blur`
- 动效偏短、可打断；形态变化可用液体 morph（菜单等），列表滚动不堆特效

**不是**整页玻璃化，也不是 2020 式全卡片 glassmorphism。

### 2.2 Glass vs Content（硬规则）

对齐 iOS 26 与 `liquid_glass_widgets` 设计哲学：

| ✅ 使用玻璃 | ❌ 保持不透明 |
|------------|--------------|
| NavigationRail / 侧栏壳、顶栏、工具栏 | 信息流视频卡、列表行 |
| 浮动播放迷你条、Sheet / 菜单 / 对话框 | 全屏背景、页面底 |
| 分段控件、滑块、开关、主 CTA（可选） | 播放器画面本体、弹幕层 |
| 设置页分组表面（可选 `GlassGroupedSection`） | 封面网格、评论正文区 |

```text
┌──────────┬────────────────────────────────────┐
│  Mica    │  搜索 / 账号（可选 Glass 控件）     │  ← chrome
│  Rail    ├────────────────────────────────────┤
│          │                                    │
│          │   Opaque content（网格 / 列表）     │  ← 内容
│          │                                    │
│          ├────────────────────────────────────┤
│          │  可选 Glass 播放 pill / Toast       │
└──────────┴────────────────────────────────────┘
```

### 2.2.1 桌面穿透（Desktop pierce）

桌面壳层在 **透明窗口** 上走 Mica / 系统材质：Rail 与 compact 底栏贴窗边，内容区不透明托盘铺满剩余空间。**不留**壳层 margin 透明空隙。

| ✅ 穿透 / 材质 | ❌ 不穿透 |
|----------------|----------|
| 壳层背景（Scaffold 透明，供原生 Mica/VE） | 信息流 / 列表 / 详情页底 |
| Rail / compact 底栏 `MicaSurface` tint | 壳层 margin 空隙（已取消） |
| 玻璃材质自身的半透明 tint | 窗口外缘圆角（交由 WM/合成器） |
| | 播放器全屏 / 直播间画面；模态正文 |

```text
┌─ 透明窗口（WM 负责外缘圆角）──────────────────┐
│ Mica Rail │ 不透明内容托盘（直角、贴边）      │
│ 导航项    │ 顶栏 · Feed / 列表               │
│           │                                   │
└──────────────────────────────────────────────┘
```

| 平台 | 实现要点 |
|------|----------|
| 共用 | `window_manager` 透明底；`DesktopWindow.desktopPierceEnabled` 门控；`flutter_acrylic` 分平台 effect；壳层 **贴边**（无 margin 空隙） |
| Linux | 透明窗 + **合成器 real-time blur**（`desktop_compositor_blur.cc`：Wayland **`ext-background-effect-v1`** 全窗 `set_blur_region`；X11 KWin `_KDE_NET_WM_BLUR_BEHIND_REGION`）；`MicaSurface` 仅轻 tint；`DesktopWallpaper` 仅无合成器 blur 时的静态兜底 |
| macOS | **`NSVisualEffectView`**：`WindowEffect.sidebar`；`MicaSurface` 近透明透传 |
| Windows | **DWM**：Win11 build ≥ 22000 → `mica`；更早 → `acrylic`；失败再退 transparent + 模拟 |

> **Important:** **禁止**用 Flutter `BackdropFilter` 糊桌面——引擎采不到 compositor 桌面像素，当前场景下不生效。Linux blur = **合成器** real-time blur；Win/macOS = DWM / VisualEffect。静态壁纸采样 ≠ live blur，只作兜底。

**Example**

```dart
// main.dart — runApp 前
await DesktopWindow.ensureInitialized();

// app_shell.dart — 贴边：无 Rail/内容 margin
Scaffold(
  backgroundColor: DesktopWindow.desktopPierceEnabled
      ? Colors.transparent
      : colors.canvas,
  body: Row(
    children: [
      MicaSurface(borderRadius: BorderRadius.zero, child: NavigationRail(...)),
      Expanded(child: OpaqueContentPanel(child: child)),
    ],
  ),
);
```

初始化失败时 `desktopPierceEnabled == false`，壳层回退不透明 canvas，功能不受影响。

### 2.3 组合规则：玻璃是托盘，不是包装纸

- `GlassCard` / `GlassContainer` / `GlassGroupedSection` 是 **底层表面**，上面放文字、图标、标准控件。
- **禁止** 在玻璃容器内再嵌套另一个折射玻璃控件（`GlassButton`、`GlassSlider`…）——内层折射会被禁用/裁切，效果变差且费 GPU。
- 交互玻璃控件自带表面，不需要再包一层 `GlassCard`。

### 2.4 质量分级（性能契约）

| `GlassQuality` | 用途 | 桌面 | 手机 / 折叠 |
|----------------|------|------|-------------|
| `standard` | **默认** chrome | Linux/Windows（Skia）主路径 | **默认**；底栏/顶栏 |
| `premium` | 静态栏全管线 | macOS 顶/底栏可用 | **仅**静止 AppBar/TabBar；列表/滚动 **禁止** |
| `minimal` | 弱机 / 省电 / 无障碍降级 | 列表误用时的兜底 | 中低端 Android **优先**；热节流时自动 |

全局：`LiquidGlassWidgets.wrap(adaptiveQuality: true)`，设备基准测试 + 热节流自动降级。

### 2.5 何时用 / 何时不用（全平台）

判断顺序：**是否 chrome 或浮层 → 是否滚动复用 → 设备能否扛住 → 无障碍是否要求降级**。

#### 应该用 Liquid Glass

| 场景 | 说明 |
|------|------|
| 桌面一级导航 chrome | **Rail 用模拟 Mica**（见下）；（可选）顶栏控件仍可 Liquid Glass |
| 移动 compact 底栏 Tab | **悬浮** `GlassTabBar`（Liquid Glass pill） |
| 模态与菜单 | `GlassDialog` / `GlassMenu` / `GlassModalSheet` / Popover |
| 浮动控件 | 迷你播放条、FAB 气质按钮、搜索 pill |
| 设置分组表面 | **可选** `GlassGroupedSection`（页内少量，非每行一片玻璃） |
| 分段 / 滑块等控件 | 在 chrome 或设置页少量使用；自带表面，勿再包 `GlassCard` |

#### 一级底栏 Tab：按平台分形态

| 平台 | 形态 | 实现 |
|------|------|------|
| **桌面宽窗**（medium+） | **Mica 侧栏** | 贴边 `MicaSurface` + `NavigationRail`；直角；无壳层空隙 |
| **移动**（Android / iOS） | **悬浮** Liquid Glass pill | `GlassTabBar.bottom` + 左右/底 margin + `SafeArea` |
| **桌面窄窗**（compact） | **贴边** Mica + icon + 文字 | `FrostedNavBar` + `extendBody`；Linux blur 走合成器，不叠 Flutter blur |

**Example — 桌面宽窗 Mica Rail**

```dart
// Windows: WindowEffect.mica / acrylic（DWM）
// macOS:   WindowEffect.sidebar（NSVisualEffectView）
// Linux:   WindowEffect.transparent + DesktopWallpaper sample plate
// 贴边：无 Padding/margin 空隙；直角；窗缘圆角交 WM
Scaffold(
  backgroundColor: pierce ? Colors.transparent : colors.canvas,
  body: Row(
    children: [
      MicaSurface(
        width: expanded ? 88 : 72,
        borderRadius: BorderRadius.zero,
        child: NavigationRail(
          backgroundColor: Colors.transparent,
          // ...
        ),
      ),
      Expanded(child: OpaqueContentPanel(child: child)),
    ],
  ),
);
```

**Example — 移动悬浮 Liquid Glass**

```dart
if (isMobileOs) {
  return Scaffold(
    extendBody: true,
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(md, 0, md, sm),
      child: GlassTabBar.bottom(tabs: ..., selectedIndex: i, onTabSelected: ...),
    ),
  );
}
```

**Example — 桌面窄窗 Mica + icon/label 贴边**

```dart
// MicaSurface 轻 tint；Linux 实时 blur 由 runner 向合成器请求，勿 BackdropFilter
Scaffold(
  extendBody: true,
  bottomNavigationBar: FrostedNavBar(
    items: [...],
    selectedIndex: index,
    onSelect: onSelect,
  ),
);
```



#### 不应该用 Liquid Glass

| 场景 | 原因 |
|------|------|
| **桌面** wide Rail | 用 **Mica**（`MicaSurface` + Windows 原生 DWM），不用 `GlassContainer` 折射 |
| **桌面** compact 底栏 Tab | 用 `MicaSurface` + icon/label，不用 `GlassTabBar` / frosted tray |
| 信息流视频卡 / 封面网格 | 滚动项 × N 会打爆 GPU；内容应不透明可读 |
| 评论楼层、动态卡片、历史行 | 同上；长列表虚拟化 + 不透明表面 |
| 播放器画面、弹幕、字幕 | 内容层；玻璃只可出现在 **控件条** |
| 全屏/沉浸播放时的大面积背景 | 避免「整页起雾」挡画面 |
| 玻璃套玻璃 | 内层折射被禁/裁切，既丑又贵 |
| 低电量 / 弱机 / Reduce Transparency | 降 `minimal` 或改不透明 elevated 表面 |
| 纯展示大表格/密集设置长页 | 可读性优先；最多顶栏玻璃 |

#### 形态速查

```text
桌面 expanded+        → 透明壳 + Mica Rail + 不透明内容托盘（直角；桌面穿透）
桌面/平板 medium      → 同上；Rail 可收起
桌面 compact 窄窗     → 贴边 FrostedNavBar（Mica + icon/文字）；Feed 全宽；extendBody
手机 compact          → 悬浮 GlassTabBar（Liquid Glass）；SafeArea + 外边距
Fold 外屏 compact     → 同手机；悬浮 Liquid Glass 底栏
Fold 内屏             → medium/expanded；竖铰链双栏；仅外壳玻璃
Flip 封面 cover       → 无 Liquid Glass；迷你播放/状态，非完整 App
Flip 全开 compact     → 同手机
Flip 半开 flex        → 上半画面零玻璃；下半控件可轻玻璃；无完整 Tab 壳
播放中（任意形态）    → 画面与弹幕零玻璃；控件条可用暗色 glass.tint.player
全屏播放路由          → 不走壳层穿透；黑底沉浸
```

手机 / **Fold（左右折）** / **Flip（上下翻盖）** 的铰链、封面与 Flex 见 [multi-platform.md](./multi-platform.md) §11.2–11.4。

---

## 3. 色彩（Color）— **已锁定**

### 3.1 策略

**单一真相：语义色板（App Palette）**。写入 `palette.dart` / `ThemeExtension`，业务只读 token。

| 做 | 不做 |
|----|------|
| 手写语义 token（bg / fg / accent / status） | **Material 3** 视觉、`ColorScheme.fromSeed` 当品牌源 |
| 强调色 **Sky 青**（玻璃友好） | **B 站粉**（`#FB7299` 及玫红/品红系 CTA） |
| cinema navy 深色 + 冷灰白浅色 | 纯 OLED 黑大面积、暖灰脏底 |
| 业务禁止 `Color(0xFF...)` | 业务硬编码色值 |

品牌一句话：**冷色电影感 + 青强调 + 玻璃 chrome**，不与官方 App 撞色。

### 3.2 品牌与角色（锁定值）

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `color.accent` / `primary` | `#0284C7` | `#38BDF8` | CTA、选中、进度、焦点环强调 |
| `color.onAccent` | `#FFFFFF` | `#0B0F1A` | accent 上的字/图标 |
| `color.secondary` | `#4F46E5` | `#818CF8` | 链接、筛选、次要强调 |
| `color.tertiary` | `#7C3AED` | `#A78BFA` | 少量点缀（活动/实验功能） |
| `color.bg.canvas` | `#F4F6FA` | `#0B0F1A` | 页面底（内容区） |
| `color.bg.elevated` | `#FFFFFF` | `#121826` | 不透明卡片 / 面板 |
| `color.bg.sunken` | `#E8ECF4` | `#070A12` | 凹陷区、输入井 |
| `color.fg.primary` | `#0F172A` | `#F8FAFC` | 主文字 |
| `color.fg.secondary` | `#475569` | `#94A3B8` | 次要文字 / meta |
| `color.fg.muted` | `#64748B` | `#64748B` | 更弱说明 |
| `color.border.subtle` | `#E2E8F0` | `#1F2937` | 分割、未选中描边 |
| `color.border.strong` | `#CBD5E1` | `#334155` | 强调描边 |
| `color.error` | `#DC2626` | `#F87171` | 错误 / 危险 |
| `color.success` | `#16A34A` | `#4ADE80` | 成功 |
| `color.warning` | `#D97706` | `#FBBF24` | 警告（清晰度/网络） |
| `color.info` | `#0284C7` | `#38BDF8` | 一般信息（与 accent 对齐） |
| `color.live` | `#EF4444` | `#F87171` | **仅**直播角标（功能色，非品牌） |
| `color.vip` | `#CA8A04` | `#EAB308` | 大会员等（克制） |

**禁用品牌色（勿作 primary/accent）：**

| 色 | 原因 |
|----|------|
| `#FB7299` / `#E11D48` / 玫红·品红系 | B 站粉 / 旧草案 seed |
| `#00A1D6` 大面积 | 官方主蓝，易被当成「假官方」 |

说明：

- Dark `canvas #0B0F1A` 极轻蓝紫，玻璃高光不脏。
- Light 避免纯白大面积，否则玻璃几乎不可见。
- `accent` **仅小面积**；页面底与侧栏禁止大块青染。

### 3.3 Theme 接入（非 M3 语义）

Flutter 仍可用 `ThemeData` 承载 token，但 **不以 M3 ColorScheme 角色为设计源**：

| 实现字段 | 映射 token |
|----------|------------|
| 自定义 `AppColors` ThemeExtension | §3.2 全表 |
| `ThemeData.colorScheme`（仅兼容第三方/基础控件） | 手填：`primary=accent`，`surface=canvas`，`onSurface=fg.primary`，`error=error`；**禁止** `fromSeed` 生成品牌 |
| `PlayerColors` ThemeExtension | §3.5 |

### 3.4 玻璃着色（Glass Tint）

玻璃自身色来自 `LiquidGlassSettings.glassColor`（**透明度 = 染色强度**），不是实心填充。

| Token | Light | Dark | 说明 |
|-------|-------|------|------|
| `glass.tint.neutral` | `rgba(255,255,255,0.10)` | `rgba(18,24,38,0.45)` | 默认 chrome |
| `glass.tint.chrome` | `rgba(255,255,255,0.14)` | `rgba(15,23,42,0.55)` | 顶栏 / Rail 略实 |
| `glass.tint.accent` | `rgba(2,132,199,0.14)` | `rgba(56,189,248,0.16)` | 选中 / 强调 pill（少用） |
| `glass.tint.player` | — | `rgba(0,0,0,0.35)` | 播放器控件条（始终暗） |

浅色模式玻璃若几乎看不见：提高 `glass.tint.*` alpha 或背景改用略有色相的 canvas，**不要**靠无限加大 blur。

### 3.5 播放器叠加层

播放器为暗底内容区，**不**跟随浅色应用主题：

| Token | 用途 | 约定 |
|-------|------|------|
| `player.scrim` | 控件渐变遮罩 | 黑 0%→60% 纵向 |
| `player.controlFg` | 图标/文字 | 近白 + 可选阴影 |
| `player.progressPlayed` | 已播放 | `accent` |
| `player.progressBuffered` | 缓冲 | 半透明白 |
| `player.progressTrack` | 轨道 | 低透明白 |
| `player.danmakuDefault` | 默认弹幕 | 白/浅描边 |
| `player.chromeGlass` | 控件玻璃 | `glass.tint.player` + 见 §4 |

实现：`ThemeExtension<PlayerColors>`。

### 3.6 对比度

- 正文与背景 **≥ 4.5:1**（WCAG AA）；大标题/图标 **≥ 3:1**。
- 玻璃上的文字：若对比不足，在文字后加 **不透明 scrim / 加粗字重**，禁止靠「再透一点玻璃」赌运气。
- 状态色不仅靠颜色，需图标或文案。

---

## 4. 玻璃材质 Token

对应 `LiquidGlassSettings` / `GlassThemeSettings`。数值为桌面默认；业务禁止魔法数。

### 4.1 材质参数

| Token | 默认 | 范围建议 | 映射 |
|-------|------|----------|------|
| `glass.blur` / frost | `6` | 3–12 | `blur` |
| `glass.thickness` | `28` | 16–40 | `thickness` |
| `glass.lightIntensity` | `0.55` | 0.3–0.8 | `lightIntensity` |
| `glass.ambientStrength` | `0.08` | 0–0.2 | `ambientStrength` |
| `glass.refractiveIndex` | `1.18` | 1.1–1.3 | `refractiveIndex` |
| `glass.saturation` | `1.35` | 1.0–1.6 | `saturation` |
| `glass.chromaticAberration` | `0.02` | 0–0.08 | 色散；桌面宜低 |
| `glass.glowIntensity` | `0.5` | 0–0.75 | 交互高光 |
| `glass.specularSharpness` | `medium` | soft/medium/sharp | 高光锐度 |
| `glass.shadowElevation` | `1.0` | 0.5–1.5 | 阴影强度倍率 |

Light / Dark 微调：

| | Light | Dark |
|--|-------|------|
| blur | 5–6 | 6–8 |
| thickness | 24–28 | 28–34 |
| lightIntensity | 0.45–0.55 | 0.55–0.7 |
| tint | 见 §3.4 | 见 §3.4 |

### 4.2 形状（玻璃与实体共用）

| Token | 圆角 | 用途 |
|-------|------|------|
| `radius.xs` | 4 | 小标签、进度端 |
| `radius.sm` | 8 | 按钮、输入、小控件 |
| `radius.md` | 12 | 默认卡片、菜单项 |
| `radius.lg` | 16 | **默认玻璃表面**、对话框 |
| `radius.xl` | 20 | 大面板、Sheet |
| `radius.full` | 999 | 胶囊 Chip、播放 pill、头像 |

视频封面：`radius.sm`–`md`；播放器画面 **0 圆角**（沉浸），外层容器可有圆角。

### 4.3 层级（玻璃代替厚重 elevation）

| 层级 | 表现 | 用途 |
|------|------|------|
| 0 | 不透明 `canvas` | 页面底 |
| 1 | 不透明 `elevated` 或极轻阴影 | 内容卡片 |
| 2 | **玻璃 standard** | Rail、顶栏、工具条 |
| 3 | 玻璃 + 更高 tint/blur | 菜单、Popover、对话框 |
| 覆盖 | 播放器 chrome / Toast | 独立叠层，不进页面 elevation 体系 |

桌面阴影比移动更轻；深度主要靠 **玻璃分层 + 背景内容**，不是大投影。

### 4.4 全局主题接入

```dart
await LiquidGlassWidgets.initialize();

runApp(LiquidGlassWidgets.wrap(
  child: const NextPiliApp(),
  adaptiveQuality: true,
  theme: GlassThemeData(
    light: GlassThemeVariant(
      settings: GlassThemeSettings(
        blur: 6,
        thickness: 26,
        glassColor: Color(0x1AFFFFFF), // glass.tint.neutral light
        lightIntensity: 0.5,
        refractiveIndex: 1.18,
        saturation: 1.35,
        chromaticAberration: 0.02,
      ),
      quality: GlassQuality.standard,
      glowColors: GlassGlowColors(primary: Color(0xFF0284C7)), // accent light
    ),
    dark: GlassThemeVariant(
      settings: GlassThemeSettings(
        blur: 8,
        thickness: 32,
        glassColor: Color(0x73121826), // glass.tint.neutral dark
        lightIntensity: 0.6,
        refractiveIndex: 1.18,
        saturation: 1.35,
        chromaticAberration: 0.02,
      ),
      quality: GlassQuality.standard,
      glowColors: GlassGlowColors(primary: Color(0xFF38BDF8)), // accent dark
    ),
  ),
));
```

屏幕骨架优先 `GlassScaffold` / 桌面自定义 Shell + `GlassPage`（见 [flutter.md](../design/flutter.md)）。

---

## 5. 字体排版（Typography）— **已锁定**

### 5.1 字体栈（锁定）

| 角色 | 字体 | 说明 |
|------|------|------|
| UI / 拉丁 | **Inter** | 唯一 UI 西文；字重 400 / 500 / 600 / 700 |
| CJK | **系统栈**（不打包整套） | 见下表 fallback |
| 等宽 | **JetBrains Mono**（可选）或系统 mono | 仅 BV 号、调试、代码；进度数字优先 Inter tabular |

**CJK fallback 顺序（`fontFamilyFallback`）：**

| 平台 | Fallback |
|------|----------|
| macOS / iOS | `PingFang SC` → `Hiragino Sans GB` |
| Windows | `Microsoft YaHei UI` → `Microsoft YaHei` |
| Linux | `Noto Sans CJK SC` → `Source Han Sans SC` → `WenQuanYi Micro Hei` |
| 通用兜底 | `sans-serif` |

实现约定：

- 用 `google_fonts` 的 **Inter**（或 assets 子集）；**不**引入 Material 默认字体作品牌。
- **不**打包 Noto 全量 CJK（体积）；中文跟系统。
- 字重：正文 400、标题/导航 500–600、强调 600–700；避免 300 在玻璃上发虚。

### 5.2 类型角色（自有 token → `TextTheme` 槽位仅作承载）

| Token | 约略尺寸 | 字重 | 场景 |
|-------|----------|------|------|
| `type.display` | 28 / 1.2 | 600 | 罕见大标题 |
| `type.headline` | 22 / 1.25 | 600 | 页面标题 |
| `type.title` | 16–18 / 1.3 | 600 | 视频详情标题 |
| `type.titleSm` | 14–15 / 1.35 | 500–600 | 卡片标题、侧栏 |
| `type.body` | 14 / 1.5 | 400 | 默认正文、简介 |
| `type.bodyLg` | 15–16 / 1.5 | 400 | 评论正文 |
| `type.meta` | 12 / 1.4 | 400 | 时间、播放量 |
| `type.label` | 13–14 / 1.2 | 500–600 | 按钮、Chip |
| `type.caption` | 11–12 / 1.3 | 500 | 角标、进度时间 |

工程可把上述映射进 `TextTheme` 的 `headline*` / `title*` / `body*` / `label*` **仅作 Flutter 槽位**，语义以 token 名为准，**不**跟 M3 type scale 绑定。

### 5.3 数字与截断

- 播放量、时长、进度：**tabular figures**（Inter `FontFeature.tabularFigures()`）。
- 大数缩写走本地化（见 [localization.md](./localization.md)）。
- 标题最多 **2 行** ellipsis；简介 **3 行** + 展开。

---

## 6. 间距与布局网格

### 6.1 基础单位

- **4dp 网格**；阶梯：`4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48`。

| Token | 值 | 用途 |
|-------|-----|------|
| `space.xs` | 4 | 图标与文字 |
| `space.sm` | 8 | 紧凑组内 |
| `space.md` | 16 | 默认内边距 |
| `space.lg` | 24 | 区块间距 |
| `space.xl` | 32 | 页面边距 |
| `space.xxl` | 48 | 大分节 |

### 6.2 页面边距

| 窗口宽度 | 水平边距 | 内容最大宽 |
|----------|----------|------------|
| < 600 | 16 | 通栏 |
| 600–839 | 24 | 通栏 |
| 840–1199 | 24–32 | 可读列可限宽 |
| ≥ 1200 | 32+ | 信息流约 **1400–1600** 居中 |

播放器可突破最大内容宽。

### 6.3 密度

| 档位 | 列表行高（约） | 适用 |
|------|----------------|------|
| `comfortable` | 64–72 | 默认 |
| `compact` | 48–56 | 高密度 / 小笔记本 |

影响 `VisualDensity`、列表 padding、导航项高度，不改变断点。

---

## 7. 图标 — **已锁定**

用 Lucide 表达动作与状态；**何时 icon-only、何时必须配可见文字** 见 §7.4–7.7。业务统一 `AppIcons.*`，禁止散落 Material / emoji 图标。

| | Example |
|--|---------|
| ✅ | 播放器播停 → icon-only + Semantics「播放」 |
| ❌ | 「登录」仅图标、无文字 |
| ✅ | Rail **展开** → 图标 + 始终可见标签 |
| ❌ | 一级导航仅靠 hover 才出标签 |

### 7.1 库

| 项 | 决定 |
|----|------|
| 图标集 | **[Lucide](https://lucide.dev)**（Outlined 线宽统一） |
| Flutter 包 | `lucide_icons` 或 `flutter_lucide`（实现时二选一写死，禁止混用多库） |
| 否决 | **Material Symbols / Icons**、CupertinoIcons 作默认集、emoji 当图标 |

选中态：同图标 + `color.accent` 或略加粗 stroke（若包支持 weight）；**不要**换一套 Filled Material 图标。

### 7.2 尺寸与热区

| Token | px | 用途 |
|-------|-----|------|
| `icon.xs` | 16 | 角标旁、极紧凑 meta |
| `icon.sm` | 20 | 工具栏默认、列表 trailing |
| `icon.md` | 24 | 导航、主操作 |
| `icon.lg` | 28 | 空状态、强调 |
| `icon.xl` | 32 | 大空状态 |

- 桌面点击热区 **≥ 32×32**；触摸目标若启用移动 **≥ 48×48**。
- 图标按钮在玻璃 chrome 上时，优先 `GlassIconButton`；内容区用标准按钮 + Lucide 子节点。
- 业务禁止散落 `Icons.*`（Material）；统一 `AppIcons.play` 等薄封装映射 Lucide 名。

### 7.3 判定：识别 → 诠释

icon-only 仅当用户能 **两步都过关** 时才允许：

| 步 | 问题 | 失败则 |
|----|------|--------|
| **识别** | 画的是什么？ | 换更清晰的 Lucide，或改用文字 |
| **诠释** | 点了会怎样？ | **禁止** icon-only；加可见文字或改纯文字 |

#### Example

| 控件 | 识别 | 诠释 | 形态 |
|------|------|------|------|
| 三角形 ▶ | 播放符号 | 开始播放 | ✅ icon-only + Semantics |
| 放大镜 | 搜索 | 打开搜索 | ✅ 紧凑 chrome 可 icon-only；桌面顶栏优先可见输入框 |
| 时钟 | 时间 / 历史？ | 「稍后再看」？ | ❌ icon-only；→ 文字或 图标+文字 |
| 心 / 星 | 喜欢？收藏？评分？ | 含义竞争 | ❌ 单靠图形；→ **写死一枚** + 数量或文案 |
| 「登录」 | — | 主路径 CTA | ❌ icon-only；→ **可见文字** |

硬约束（细节见 §7.4–7.8）：

| 规则 | 约定 |
|------|------|
| 5 秒定不下隐喻 | **禁止**新画图标；用文字 |
| 导航标签 | 展开态 **始终可见**；禁止只靠 hover 出字 |
| 可操作控件 | 必须有可访问名称（可见字或 `Semantics`） |
| Tooltip | 桌面 icon-only 配 Tooltip；**禁止**把完成任务必需信息只放 Tooltip |
| 已有可见标签 | 不必再 Tooltip；旁衬图标排除语义 |

外部依据（NN/g Icon Usability、Apple HIG Buttons/Icons、WCAG 1.1.1 / 4.1.2）见文首参考；**以本节与 §7.4–7.7 为准**。

### 7.4 何时使用图标

满足下列条件时 **应当** 用图标（可单独或与文字组合）：

| 条件 | 说明 | 示例 |
|------|------|------|
| **接近「通用」隐喻** | 跨产品语义稳定；优先平台/竞品已统一的符号 | 播放/暂停、搜索（放大镜）、设置、关闭、全屏、音量/静音、下载、分享、返回 |
| **工具栏 / 播放器 chrome 空间紧** | 一排操作并排，文字会挤爆；媒体控件用户已有心智模型 | 播放器底栏：播停、弹幕、全屏 |
| **与文字并列作扫描锚点** | 不单独承担语义；图标只增强扫视 | 菜单「收藏」+ 书签；设置行 leading 分类标 |
| **状态形态可区分** | 同一隐喻的开/关形态，不只靠颜色 | 静音斜线、弹幕开/关、点赞实心/空心 |
| **空状态 / 错误插画位** | 降低空白突兀；**必须**配说明句 + 操作 | 无收藏：图标 + 文案 +「去发现」 |
| **导航折叠仅图标** | Rail 收起、窄窗底栏 | **展开态必须图标+文字**；折叠态 icon-only + Tooltip + Semantics |

**选型规则：**

- 5 秒内想不出隐喻 → **不要画新图标**，用文字。
- 同一动作全产品 **固定一枚** Lucide（搜索永远 magnifying glass）。
- 优先 **简单示意** 线标，避免写实细节（小尺寸不可辨）。
- 新图标上线前做识别/诠释抽测（口头：「这是啥 / 点了怎样」）。

### 7.5 何时不使用（或禁止 icon-only）

| 反模式 | 原因 | 正确做法 |
|--------|------|----------|
| **非常规 / 产品私有概念** | 无稳定隐喻，诠释失败 | 「稍后再看」「分 P」「充电专属」→ 文字或 图标+文字 |
| **导航只靠 icon + hover 标签** | 标签不可见；触摸无 hover | Rail **展开显示文字**；折叠才 icon-only |
| **主 CTA / 破坏性仅图标** | 误触成本高；文字更清楚 | 「登录」「发送」「删除账号」→ 文字按钮 |
| **心/星等竞争隐喻** | 收藏 / 喜欢 / 评分混用 | 点赞与收藏各写死一枚，并 **配数量或文案** |
| **时钟=历史 等牵强比喻** | 识别过、诠释不过 | 「稍后再看」勿仅用时钟；用文字入口 |
| **用图标代替错误/成功全文** | 无障碍与文案规范 | Toast/行内完整句子；图标可选 |
| **列表行堆 3+ 装饰标** | 噪音、拖慢扫描 | ≤1 leading 类型 **或** trailing 操作 |
| **图标内嵌字/数字** | 难本地化 | 角标用独立 `Badge` 文本 |
| **emoji / Material / Cupertino 混搭** | 已锁 Lucide | `AppIcons.*` only |
| **为「满」而塞** | 无信息增量 | 删；留白优于假密度 |
| **Tooltip 承载关键信息** | 触摸无可靠 hover | 密码规则、必填说明等 **常显**，不进 Tooltip |

**判定口诀：**

1. 去掉图标后用户是否仍知道点什么？→ 是：图标可作增强。否：必须加 **可见** 文字。  
2. 5 秒内能否确定隐喻？→ 否：纯文字。  
3. 是否一级导航或主任务入口？→ 是：默认 **图标+文字**（折叠场景例外见上）。

### 7.6 三种组合：icon-only / 图标+文字 / 纯文字

| 形态 | 何时用 | 硬约束 |
|------|--------|--------|
| **Icon-only** | 空间极紧 **且** 隐喻接近通用：播放器控件、Rail 折叠、工具栏次要操作、关闭/更多 | ① 桌面 **Tooltip**（指针/键盘 focus）② `Semantics` 名称（WCAG）③ **不得**把完成任务必需的信息只放 Tooltip ④ 触摸无 hover 时依赖学习与 Semantics，关键导航勿长期仅 icon ⑤ 热区达标 |
| **图标 + 文字** | 导航展开、菜单、设置、需要扫视的按钮（Material 默认形态） | 文字是 **主语义**；图标不得与文案矛盾；LTR 图标在前；间距 `space.xs`–`sm`；**已有文字则不必重复 Tooltip**（Fluent） |
| **纯文字** | 对话框主/次按钮、表单提交取消、账号与破坏性、动词短语已够清楚（Apple） | 不硬凑图标；危险靠文案 + 确认 |

桌面约定：

- **NavigationRail**：展开 = 图标+标签（标签始终可见）；折叠 = icon-only + Tooltip。  
- **菜单**：文字为主；常用项可 leading 图标（克制）。  
- **顶栏搜索**：桌面优先 **可见输入框** + 可选放大镜；**禁止**桌面仅一枚搜索图标作唯一入口。窄窗可收成 icon。

### 7.7 NextPili 场景速查

| 场景 | 图标？ | 形态 | 备注 |
|------|--------|------|------|
| 播放 / 暂停 / 全屏 / 静音 | ✅ | icon-only | 通用媒体隐喻；Semantics 必备 |
| 弹幕开关 | ✅ | icon-only 或 图标+短标签 | 形态区分开/关；见 copy |
| 清晰度 / 倍速 | ⚠️ | **文字为主** | 菜单写「1080P」「1.5x」；入口可小图标 |
| 点赞 / 投币 / 收藏 / 分享 | ✅ | 播放页 icon-only + 数量 | 语义固定；未登录引导用 **文字** |
| 稍后再看 | ⚠️ | **文字** 或 图标+文字 | 禁止仅时钟/书签无标签当唯一入口 |
| 一级导航 | ✅ | 展开：图标+文字；折叠：icon-only | 标签 ARB；**禁止**展开态藏标签 |
| 「登录」「发送评论」「退出登录」 | ❌ icon-only | 纯文字或图标+文字 | 主路径 CTA |
| 「删除」「清空历史」 | ❌ icon-only | 文字 + 确认 | 可并列 trash |
| 视频卡 meta | ✅ 可选 | 小图标+数字 **或** 纯数字 | 全产品统一一种 |
| 评论回复 / 举报 | ⚠️ | 文字链或菜单文字 | 举报勿仅 flag |
| 空状态 / 失败 | ✅ | 图标 + 说明 + 按钮文字 | §8.8 |
| 设置行 | ⚠️ | 可选 leading + **标题文字** | 勿叠无意义装饰 |
| 未读角标 | ✅ | 数字/圆点 | 不替换导航标签 |
| 分区导航 | ❌ emoji 墙 | 分区名文字 | |

### 7.8 无障碍与实现

Icon-only 必须同时具备桌面 **Tooltip** 与 **`Semantics` 名称**；label 写职责动词，不写外观（[copy.md](./copy.md)）。

#### Example

```dart
Tooltip(
  message: l10n.play,
  child: Semantics(
    button: true,
    label: l10n.play, // 「播放」，不是「图标」
    child: IconButton(icon: Icon(AppIcons.play), onPressed: onPlay),
  ),
);
```

读屏得到职责「播放」；指针悬停得到同义 Tooltip。

| 规则 | 约定 |
|------|------|
| 已有可见文字的按钮 | 用可见字作名称；旁衬图标 `excludeFromSemantics`，避免「收藏，收藏」 |
| 状态 | **禁止**只靠颜色；形态差分 + 文案/Semantics |
| 装饰图标 | 排除语义树 |
| 本地化 | 图标不承载需翻译句子；禁止谐音梗隐喻 |

### 7.9 版本说明（图标章）

| 版本 | 说明 |
|------|------|
| v0.3 | 锁定 Lucide、尺寸 token |
| v0.4 | 增补判定模型（识别→诠释）、何时用/不用、组合形态、场景速查 |

---

## 8. 组件约定

### 8.1 按钮

| 类型 | 用途 | 实现倾向 |
|------|------|----------|
| 主操作 | 登录、发送 | `GlassButton` 或 filled（`accent` 底 + `onAccent` 字）；**文字必现**，图标可选 |
| 次要 | 取消、次要动作 | Outlined / Text（border / fg token）；**纯文字优先** |
| 图标 | 播放器、工具栏、折叠导航 | `GlassIconButton`（chrome）/ 内容区图标按钮 + Lucide；**仅当符合 §7.3–7.5** |
| 危险 | 退出、删除 | `error` 色 + **文字** + 确认；可并列 trash 图标，禁止 icon-only |

### 8.2 视频卡（内容区 · 不透明）

```text
┌─────────────────────┐
│       封面          │  16:9；角标：时长 / 直播 / 4K
│  ▶ 播放量  弹幕数    │  可选 hover 浮层（桌面）
├─────────────────────┤
│ 标题（最多 2 行）    │
│ UP 主 · 日期 · 分区  │  meta = bodySmall
└─────────────────────┘
```

- 表面：`color.bg.elevated` + `radius.md`；**不用** `GlassCard` 刷信息流。
- 桌面 hover：轻抬升 + 快捷操作；焦点：可见 focus ring。

### 8.3 导航

| 形态 | 场景 | 材质 |
|------|------|------|
| NavigationRail / 自定义 Rail | 中等及以上桌面宽 | 玻璃 chrome |
| 顶栏搜索 | 全局 | 玻璃 / `GlassSearchBar` |
| NavigationBar | 窄窗 / 未来移动 | 玻璃 |
| Tabs / Segmented | 推荐·热门·排行 | `GlassSegmentedControl` 或自绘 token 分段 |
| Drawer | 更多入口、多账号 | 玻璃 Sheet 气质 |

详见 [multi-platform.md](./multi-platform.md)、[interaction.md](./interaction.md)。

### 8.4 列表与网格

- 信息流：宽屏多列、窄屏单/双列；**虚拟滚动**。
- 评论、动态：单列；分隔用间距或 `outlineVariant`，避免厚 divider。

### 8.5 输入

- 搜索：顶栏；清空 + 历史。
- 评论：多行；快捷键见 interaction。
- 设置表单：内容区标准输入为主；分组可用 `GlassGroupedSection`。

### 8.6 对话框与菜单

- 破坏性：明确后果 + 确认。
- 桌面优先 **Context menu** / `GlassMenu`。
- 模态：`GlassDialog` / `GlassModalSheet`；scrim 保证文字可读。

### 8.7 进度与加载

| 场景 | 模式 |
|------|------|
| 首屏 | 骨架屏优先 |
| 列表分页 | 底部线性 progress 或静默插入 |
| 播放器缓冲 | 中心指示 + 缓冲段 |
| 按钮提交 | 按钮内 loading |

### 8.8 空状态与错误

- 空：图标 + 一句说明 + 一个主操作。
- 错误：可读原因 + 重试；不暴露堆栈。
- 未登录：说明「登录后可用」。

---

## 9. 主题模式

| 模式 | 行为 |
|------|------|
| `system` | 跟随 OS（默认） |
| `light` | 强制浅色 |
| `dark` | 强制深色 |

播放器 UI 在浅色应用主题下仍用暗色控件层（§3.5）。  
纯黑 AMOLED 变体后续可选。

Reduce Transparency：玻璃降为更高不透明 / `minimal`；由库默认处理，应用不另开开关（设置页可后续暴露「性能-画质」）。

---

## 10. 实现库（ADR）

### ADR-UX-001：采用 `liquid_glass_widgets`

| 项 | 决定 |
|----|------|
| 包 | [`liquid_glass_widgets`](https://pub.dev/packages/liquid_glass_widgets) `^0.22.1` |
| 源码 | https://github.com/sdegenaar/liquid_glass_widgets |
| 渲染 | 内嵌 vendored `liquid_glass_renderer`（MIT，whynotmake.it）；**不**再直接依赖 renderer 包 |
| 平台 | iOS / Android / macOS / Windows / Linux / Web 均声明支持 |
| 桌面路径 | macOS → Impeller 全管线；**Windows / Linux → Skia lightweight shader**（`standard`） |
| Flutter | **≥ 3.41.0**（包约束）；P0 工程对齐该下限 |
| 无障碍 | Reduce Motion / Reduce Transparency 默认尊重 |
| 备选否决 | 仅 `liquid_glass_renderer`：缺完整组件与主题；自研 BackdropFilter：达不到 Liquid Glass 质感且难统一 |

### 10.1 工程落点

与 [design/flutter.md](../design/flutter.md) 对齐：

```text
app/lib/core/theme/
  palette.dart            # §3 色板常量（accent sky，无 B 站粉）
  app_colors.dart         # ThemeExtension<AppColors>
  text_themes.dart        # Inter + CJK fallback + type token
  player_colors.dart      # ThemeExtension
  glass_theme.dart        # GlassThemeData 组装（light/dark）
  spacing.dart
  shapes.dart
  app_theme.dart          # ThemeData 承载 token（非 M3 视觉）
app/lib/core/icons/
  app_icons.dart          # Lucide 语义封装（play / home / search…）
app/lib/core/adaptive/
  desktop_window.dart     # Win Mica · macOS VisualEffect · Linux transparent
  desktop_wallpaper.dart  # Linux 壁纸路径（GNOME/KDE/XFCE…）→ 采样 plate
  desktop_backdrop_sync.dart  # 主题亮暗 → Win/macOS 系统材质
app/lib/core/widgets/
  mica_surface.dart       # Rail chrome（native 透传 / Linux 采样 / tint）
  frosted_nav_bar.dart    # 窄窗贴边 Mica + icon/label 底栏
  glass/                  # 对库的薄封装（可选）：AppGlassScaffold 等
app/lib/features/shell/
  app_shell.dart          # 透明壳 + 不透明内容托盘 + Mica Rail / TabBar
```

启动：

```text
WidgetsFlutterBinding.ensureInitialized()
await LiquidGlassWidgets.initialize()
await DesktopWindow.ensureInitialized()   # Win Mica · macOS sidebar VE · Linux transparent
await RustLib.init()
await coreApi.bootstrap(...)
runApp(
  LiquidGlassWidgets.wrap(
    adaptiveQuality: true,
    theme: nextPiliGlassTheme,
    child: ProviderScope(child: NextPiliApp()),  # builder 内 DesktopBackdropSync
  ),
)
```

### 10.2 使用边界

| 允许 | 禁止 |
|------|------|
| chrome 用 `Glass*` | 信息流每张视频卡 `GlassCard` |
| 静态栏可 `premium`（macOS） | 滚动列表 `premium` |
| token 改主题 | 业务里散落 `LiquidGlassSettings(...)` 魔法数 |
| `AdaptiveGlass` / `Glass*` | 直接使用底层 `LiquidGlass`（Impeller-only，Skia 上可能空白） |

---

## 11. 验收清单（设计规范）

- [ ] 无业务硬编码色值 / blur / thickness（除 token 定义处）
- [ ] **无** B 站粉 / 玫红作 accent；accent 为 Sky `#0284C7` / `#38BDF8`
- [ ] **无** Material Symbols / `Icons.*` 作默认图标；统一 Lucide / `AppIcons.*`
- [ ] 正文字体为 Inter + 系统 CJK fallback；无整包 CJK 字体
- [ ] **不**以 M3 / `ColorScheme.fromSeed` 为品牌色源
- [ ] 信息流卡片不透明；玻璃仅出现在 chrome / 浮层
- [ ] 浅色 / 深色切换无「消失」图标或文字；玻璃上文字对比达标
- [ ] Linux / Windows 以 `standard` 可流畅滚动；无列表 `premium`
- [ ] Reduce Motion / Reduce Transparency 下可完成核心路径
- [ ] 视频卡截断、封面比例、meta 层级一致
- [ ] **图标**：Rail 展开有可见标签；登录/发送/删除非 icon-only
- [ ] **图标**：icon-only 均有 Tooltip（桌面）+ Semantics；5 秒想不出隐喻处用了文字
- [ ] **图标**：稍后再看等私有概念非「仅图标」入口；无 emoji 控件
- [ ] 空状态 = 图标 + 说明句 + 主操作文字（非孤图标）
- [ ] 焦点环在键盘导航下可见
- [ ] Flutter ≥ 3.41；`LiquidGlassWidgets.initialize` 在 `runApp` 前调用

---

## 12. 变更记录

| 版本 | 说明 |
|------|------|
| v0.1 | 初稿：M3 主路径 |
| v0.2 | 确立 Liquid Glass 语言；锁定色板与 glass token；选定 `liquid_glass_widgets` |
| v0.2.1 | 补充何时用/不用玻璃；手机与折叠质量策略交叉引用 multi-platform |
| v0.3 | **锁定**配色（Sky accent，弃 B 站粉）、字体（Inter + 系统 CJK）、图标（Lucide）；明确 **不用 M3 视觉** |
| v0.4 | 图标章：判定模型 + 何时用/不用 + 场景速查 |
| v0.5 | 桌面穿透：透明窗口 + chrome 玻璃 + 不透明内容托盘（§2.2.1） |
| v0.5.1 | compact 底栏：桌面 frosted 贴边；移动端恢复悬浮 Liquid Glass |
| v0.5.2 | 桌面 compact 底栏去掉 frosted 托盘；壳层托盘/Rail 直角，窗缘圆角交 WM |
| v0.5.3 | 桌面 chrome 保留 Mica：Rail + compact 底栏均走 `MicaSurface`（直角）；仍不用 frosted tray |
| v0.5.4 | 壳层贴边（取消 margin 透明空隙）；Linux compact 曾误用 BackdropFilter |
| v0.5.5 | 撤销 Flutter 桌面 blur；Linux 改合成器 real-time blur |
| v0.5.6 | Wayland 主路径改为 `ext-background-effect-v1`（wayland-scanner）；X11 仍 KWin atom |
