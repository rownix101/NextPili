# Flutter 应用设计（`app/`）

> 状态：草案 v0.2  
> FFI 约定：[ffi.md](./ffi.md) · 播放适配：[media.md](./media.md)  
> UX 规范：[ux 索引](../ux/README.md) · 视觉/图标：[ux/design-system.md](../ux/design-system.md) · 交互/触觉：[ux/interaction.md](../ux/interaction.md)

---

## 1. 职责

- 桌面 UI：导航、列表、详情、播放页、设置、登录。
- 调用 FRB 生成的 API；用 Riverpod 管理展示状态。
- **不**实现 B 站签名、Cookie 持久化、playurl 解析。
- 外观与交互语义遵循 `docs/ux/*`，本文只约定工程结构与状态组织。
- 视觉语言：**Liquid Glass**；实现库 **`liquid_glass_widgets`**（见 design-system ADR-UX-001）。

---

## 2. 目录结构

```text
app/lib/
  main.dart                 # 绑定 Flutter、init 玻璃 + Rust、runApp
  app.dart                  # MaterialApp / router
  bridge/
    frb/                    # 生成代码（禁止手改）
    core_api.dart           # 薄封装：错误转换、单例
    fake_core_api.dart      # 测试用
  core/
    theme/                  # palette、AppColors、TextTheme(Inter)、GlassThemeData、PlayerColors（见 ux/design-system）
    icons/                  # Lucide 语义封装 AppIcons（用/不用见 ux/design-system §7）
    haptics/                # 语义 Haptics.selection/success/…（见 ux/interaction §6.4）
    motion/                 # 时长、曲线、路由转场（见 ux/motion）
    adaptive/               # 断点、Shell 变体（见 ux/multi-platform）
    router/
    widgets/                # 跨 feature 通用组件
      glass/                # 可选：对 liquid_glass_widgets 的薄封装
    utils/
  features/
    shell/                  # 导航脚手架（玻璃 Rail / 顶栏）
    auth/                   # 登录、账号
    home/                   # 推荐、热门
    video/                  # 详情
    player/                 # 播放页 + PlayerAdapter
    search/
    user/                   # 历史、收藏入口等
    settings/
  l10n/                     # ARB + gen-l10n（见 ux/localization）
```

原则：

- **按 feature 分**，不按 `screens/` + 巨大 `services/` 堆业务。
- feature 内可有 `data/`（只调 bridge）、`presentation/`、`providers.dart`。
- 共享组件才进 `core/widgets`。
- 主题 / 玻璃 / 图标 / 触觉 / 动效 / 断点 **集中在 core/**，业务 feature 禁止魔法色值、魔法时长、散落 `HapticFeedback.*` / `Icons.*` / `LiquidGlassSettings`。
- 控件形态（icon-only vs 文字）与是否震动：**先查** `docs/ux`，再写 UI。

---

## 3. 启动顺序

```text
WidgetsFlutterBinding.ensureInitialized()
await LiquidGlassWidgets.initialize()   # 预热 shader；须在 runApp 前
await RustLib.init()
await coreApi.bootstrap(BootstrapConfig(
  dataDir: ...,
  cacheDir: ...,
  logLevel: ...,
))
final ver = await coreApi.apiVersion()
// major 检查
runApp(
  LiquidGlassWidgets.wrap(
    adaptiveQuality: true,
    theme: nextPiliGlassTheme,          # core/theme/glass_theme.dart
    child: ProviderScope(child: NextPiliApp()),
  ),
)
```

路径：

| 平台 | data 示例 |
|------|-----------|
| Linux | `~/.local/share/nextpili` |
| Windows | `%APPDATA%/nextpili` |
| macOS | `~/Library/Application Support/nextpili` |

使用 `path_provider` 取目录。

### 3.1 玻璃使用边界（工程）

| 区域 | 做法 |
|------|------|
| Shell / 顶栏 / 菜单 / Sheet | `GlassScaffold` / `GlassAppBar` / `Glass*` 或桌面自定义 Shell + `GlassPage` |
| 首页视频网格、评论列表 | **不透明** Material / 自定义卡片；禁止每卡 `GlassCard` |
| 播放器画面 | 无玻璃；控件层可用暗色玻璃 tint（player token） |
| 质量 | 默认 `standard`；滚动子树禁止 `premium`；直接使用底层 `LiquidGlass` 禁止 |

完整 token 与 ADR：[ux/design-system.md](../ux/design-system.md) §2 / §4 / §10。

---

## 4. 状态管理（Riverpod）

### 4.1 分层

```text
coreApiProvider          →  Bridge 单例
authStateProvider        →  订阅 Auth 事件 + 首次 auth_state()
feature Notifiers        →  拉列表 / 详情 AsyncValue
```

### 4.2 约定

- 服务端列表：**不在 Flutter 做第二套业务真相**；最多做 UI 缓存（已加载页）。
- `AsyncValue` 表达 loading/error/data；错误映射为用户可读文案（按 `ErrorKind`）。
- 全局 `Unauthenticated`：listener 统一跳转登录，避免每个 feature 复制。

### 4.3 示例：推荐

```text
feedProvider = AsyncNotifier
  build() => core.feedRecommend(freshIdx: 0, ps: 20)
  refresh() / loadMore() 持有 fresh_idx
```

---

## 5. 路由

推荐 `go_router`（桌面深链/返回栈清晰）：

```text
/ login
/ home
/ video/:bvid
/ video/:bvid/play?cid=
/ search
/ settings
/ user/history
...
```

播放可为详情的全屏子路由或独立路由（桌面可考虑多窗口，后期）。

---

## 6. 桌面 UX 要点

- 宽屏：`NavigationRail` + 内容区；窄窗回落导航栏。
- 列表：虚拟滚动（`ListView.builder`）；封面 `CachedNetworkImage` 或等价。
- 键盘：空格播放/暂停、方向键 seek、F 全屏（播放页 Focus）。
- 窗口：记住大小/位置（可选 `window_manager`）。

---

## 7. Feature 与 MVP 对应

| Feature | MVP 阶段 | 依赖 core API |
|---------|----------|---------------|
| shell | P0 | — |
| auth | P1 | login_sms_*, login_qr_* (desktop/tablet), auth_state |
| home | P2 | feed_recommend, feed_popular |
| video | P2 | video_detail |
| player | P3 | play_url, playback_start/stop, danmaku |
| search | P5 | search_* |
| user | P5 | history, fav... |
| settings | P1 起 | proxy, qn, slots |

---

## 8. 与 bridge 的错误处理

```text
try {
  await coreApi.xxx()
} on AppException catch (e) {
  switch (e.kind) {
    case ErrorKind.unauthenticated: ...
    case ErrorKind.riskControl: ...
    default: showError(e.message);
  }
}
```

封装：`Future<T> guard(Future<T> Function())` 统一 toast（可选）。

---

## 9. 主题、玻璃与设置

- **视觉**：Liquid Glass chrome + **自有语义 Token**（`AppColors` / `GlassThemeData` 等）；**不用** Material 3 视觉 / `ColorScheme.fromSeed` 作品牌源；亮/暗/跟随系统。
- **依赖**：`liquid_glass_widgets: ^0.22.1`（Flutter ≥ 3.41）；色板、图标、触觉见 `core/theme/` · `core/icons/` · `core/haptics/`。
- 默认清晰度等：**写入 Rust settings**（见 [store.md](./store.md)），设置页读写均走 bridge。
- 主题模式 / 玻璃画质 / 触感开关可先放 Flutter 本地，避免阻塞 P1；后续可同步 Rust store。

---

## 10. 测试

| 类型 | 做法 |
|------|------|
| widget | `ProviderScope` overrides + `FakeCoreApi` |
| golden | 关键空态/错误态（可选） |
| integration | 后期；依赖编译 rust lib |

禁止 widget 测里访问真实网络。

---

## 11. 依赖方向（Dart）

```text
features/* → bridge, core/widgets, core/router
bridge     → frb 生成代码
core/*     → 不依赖 features
```

禁止 `features/a` 直接 import `features/b` 的内部文件；跨 feature 走 router 参数或共享 core 模型。

---

## 12. 代码风格

- 与团队 Dart 分析器 / `flutter lints` 一致。
- UI 字符串后期 l10n；MVP 可中文硬编码集中在 feature。
- 不做「上帝 Service」；能放 Notifier 的逻辑不放 static 单例。
