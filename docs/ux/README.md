# NextPili UX / 设计规范索引

> 状态：草案 v0.3  
> 适用范围：Flutter 表现层（桌面优先；移动端为后续可选目标）  
> 相关：[Documentation](../README.md) · [架构](../architecture.md) · [API](../api/README.md) · [Flutter 工程](../design/flutter.md)
> 写法：[Documentation Style Pathway](../writing.md)

本目录定义 **产品外观、交互、动效、多平台与本地化** 的立项约定，供设计评审、UI 实现与验收使用。  
工程分层、FFI、鉴权等见 `docs/architecture.md` 与 `docs/design/*`；本文不重复协议与存储细节。

---

## 1. 文档地图

| 文档 | 内容 |
|------|------|
| [design-system.md](./design-system.md) | **视觉语言 Liquid Glass**、配色、玻璃材质 token、组件、主题、实现库 ADR |
| [interaction.md](./interaction.md) | 人机交互：信息架构、导航、手势/指针/键盘、播放器控件、反馈与错误 |
| [motion.md](./motion.md) | 动效设计：原则、时长/缓动 token、页面转场、列表与播放器动效 |
| [multi-platform.md](./multi-platform.md) | 多平台适配：窗口尺寸、断点、导航形态、输入设备、系统集成 |
| [copy.md](./copy.md) | **产品文案**：语气、句式、按钮/空态/错误；对齐 Apple HIG Writing |
| [localization.md](./localization.md) | 本地化与国际化：ARB、复数、日期数字、RTL、区域设置 |

---

## 2. 产品语境（设计侧）

| 项 | 约定 |
|----|------|
| 产品形态 | 桌面端优先的 B 站第三方客户端（Linux / Windows / macOS） |
| 核心路径 | 推荐/热门、搜索、播放（含弹幕/清晰度）、评论、历史/收藏、动态、直播、番剧 |
| 视觉语言 | **Liquid Glass**：玻璃用于导航/控制层；内容区不透明、可读 |
| UI 技术 | Flutter + **[liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets)**（玻璃）+ **自有语义 Token**（**不用 M3 视觉**） |
| 配色 / 字 / 图标 | Sky accent · Inter + 系统 CJK · Lucide（见 design-system） |
| 非目标 | 不模仿官方 App 像素级；**不用 B 站粉**；不以移动端竖屏信息流为默认布局；不做插件主题市场（首期）；不做整页玻璃化 |

设计原则一句话：**内容优先、chrome 可玻璃、桌面效率、可访问、可本地化。**

---

## 3. 原则摘要

1. **内容优先**：视频封面、标题、进度与弹幕是主角；玻璃只服务 chrome 与浮层。
2. **Glass vs Content**：信息流卡片、评论列表、播放器画面保持不透明；Rail / 顶栏 / 菜单 / Sheet 可用玻璃。
3. **效率优先（桌面）**：键盘可达、列表密度可调、多窗/分栏可选、减少模态打断。
4. **可预测**：相同操作相同反馈；播放器快捷键对齐业界常见约定（见 interaction）。
5. **自适应而非「假原生」**：统一 Liquid Glass + 自有 token；在 macOS/Windows/Linux 上尊重系统习惯（滚动条、菜单、窗口控制）。
6. **性能分级**：默认 `GlassQuality.standard`；静态栏可 `premium`（Impeller）；列表禁用重玻璃。
7. **无障碍默认**：对比度、焦点环、语义标签；Reduce Motion / Reduce Transparency 由库默认尊重。
8. **本地化内建**：文案不硬编码；布局预留扩展；数字/时间走 locale。
9. **文案清晰有用**：对齐 Apple Writing——清楚、简练、可行动；见 [copy.md](./copy.md)。

---

## 4. 与架构文档的边界

| 关注点 | 归属 |
|--------|------|
| 主题 token、玻璃材质、组件视觉、动效时长 | `docs/ux/*` |
| 路由结构、页面状态、Riverpod、依赖接入 | [design/flutter.md](../design/flutter.md) |
| 播放地址、清晰度选择逻辑 | Rust `media` + API |
| Cookie / 签名 | Rust `auth` / `http`，UI 不可见 |
| 非敏感偏好 | 主题可 Flutter 本地；默认清晰度/代理/弹幕策略等见 [design/store.md](../design/store.md) |

---

## 5. 已锁定决策（速查）

| 决策 | 值 |
|------|-----|
| 视觉语言 | Liquid Glass（内容不透明 + chrome 玻璃） |
| 实现库 | `liquid_glass_widgets` `^0.22.1` |
| 默认玻璃质量 | `GlassQuality.standard` + `adaptiveQuality: true` |
| 玻璃用 / 不用 | chrome·浮层用；Feed/评论/画面不用（见 design-system §2.5） |
| 手机 / 折叠 | P2 实现；含 **Fold（左右）** 与 **Flip（翻盖）**；同断点；Flip 另有封面 / 半开 Flex |
| **配色 accent** | Light `#0284C7` / Dark `#38BDF8`（Sky；**非** B 站粉） |
| 深色画布 | `#0B0F1A`（cinema navy） |
| 浅色画布 | `#F4F6FA` |
| **字体** | Inter（UI）+ 系统 CJK fallback |
| **图标** | Lucide（Outlined） |
| **UI 底座** | 自有语义 Token；**不用 Material 3 视觉** |
| Flutter 下限 | ≥ 3.41.0（库约束） |

细节与 token 表见 [design-system.md](./design-system.md)。

---

## 6. 版本与变更

- 文档版本与 `architecture.md` 同步用草案号（当前 UX **v0.3**）。
- 变更影响实现时：先改本文与 design-system，再在 PR 中说明破坏性（token 改名、断点调整、换库等）。
- Token 命名以 **语义** 为准（如 `color.bg.canvas`、`glass.blur`），实现层映射到 `ThemeExtension` / `GlassThemeData`（非 M3 seed）。

| 版本 | 说明 |
|------|------|
| v0.1 | 初稿：M3 主路径 |
| v0.2 | 确立 Liquid Glass；锁定配色与 `liquid_glass_widgets` |
| v0.3 | 锁定 Sky accent / Inter / Lucide；明确不用 M3 与 B 站粉 |
