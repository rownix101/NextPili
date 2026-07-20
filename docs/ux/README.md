# NextPili UX / 设计规范索引

> 状态：草案 v0.4  
> 适用范围：Flutter 表现层（桌面优先；移动端为后续可选目标）  
> 相关：[Documentation](../README.md) · [架构](../architecture.md) · [API](../api/README.md) · [Flutter 工程](../design/flutter.md)
> 写法：[Documentation Style Pathway](../writing.md)

本目录定义 **产品外观、交互、动效、多平台与本地化** 的立项约定，供设计评审、UI 实现与验收使用。  
工程分层、FFI、鉴权等见 `docs/architecture.md` 与 `docs/design/*`；本文不重复协议与存储细节。

---

## 1. 文档地图

| 文档 | 内容 |
|------|------|
| [design-system.md](./design-system.md) | Liquid Glass、token、**图标用/不用**、组件、主题、ADR |
| [interaction.md](./interaction.md) | 信息架构、导航、输入、播放器、**视觉/触觉反馈**、错误 |
| [motion.md](./motion.md) | 动效原则、时长/缓动 token、转场与微交互 |
| [multi-platform.md](./multi-platform.md) | 断点、导航壳、输入设备（含触觉能力）、系统集成 |
| [copy.md](./copy.md) | 产品文案；与图标标签 / Semantics 文案对齐 |
| [localization.md](./localization.md) | ARB、复数、RTL、区域 |

### 1.1 反馈通道（读法）

| 通道 | 定义处 | 一句话 |
|------|--------|--------|
| 视觉状态 / 组件 | [design-system](./design-system.md) | 颜色、玻璃、按钮形态 |
| **图标** | [design-system §7](./design-system.md#7-图标--已锁定) | 何时 icon-only / 图标+字 / 纯文字 |
| **触觉** | [interaction §6.4](./interaction.md#64-触觉--震动反馈haptics) | 语义 token、场景表、可关可降级 |
| 动效 | [motion](./motion.md) | 时长与可打断 |
| 文案 | [copy](./copy.md) | 可见字与读屏职责句 |

评审 UI 时按通道扫一遍：视觉 → 图标形态 → 触觉是否该震 → 文案是否自足。

---

## 2. 产品语境（设计侧）

| 项 | 约定 |
|----|------|
| 产品形态 | 桌面端优先的 B 站第三方客户端（Linux / Windows / macOS） |
| 核心路径 | 推荐/热门、搜索、播放（含弹幕/清晰度）、评论、历史/收藏、动态、直播、番剧 |
| 视觉语言 | **Liquid Glass**：玻璃用于导航/控制层；内容区不透明、可读 |
| UI 技术 | Flutter + **[liquid_glass_widgets](https://pub.dev/packages/liquid_glass_widgets)**（玻璃）+ **自有语义 Token**（**不用 M3 视觉**） |
| 配色 / 字 / 图标 | Sky accent · Inter + 系统 CJK · Lucide（用/不用见 design-system §7） |
| 反馈 | 视觉为主；触觉增强且可关；文案自足（不靠图标/震动单独传义） |
| 非目标 | 不模仿官方 App 像素级；**不用 B 站粉**；不以移动端竖屏信息流为默认布局；不做插件主题市场（首期）；不做整页玻璃化 |

设计原则一句话：**内容优先、chrome 可玻璃、桌面效率、可访问、可本地化。**

---

## 3. 原则摘要

1. **内容优先**：视频封面、标题、进度与弹幕是主角；玻璃只服务 chrome 与浮层。
2. **Glass vs Content**：信息流卡片、评论列表、播放器画面保持不透明；Rail / 顶栏 / 菜单 / Sheet 可用玻璃。
3. **效率优先（桌面）**：键盘可达、列表密度可调、多窗/分栏可选、减少模态打断。
4. **可预测**：相同操作 → 相同视觉/触觉/文案反馈；播放器快捷键对齐业界约定（interaction）。
5. **图标有义才用**：通用隐喻或作文字锚点；主 CTA / 私有概念 / 展开导航 **禁止仅靠 icon**（design-system §7）。
6. **触觉信号非噪音**：用户意图或结果才震；滚动/弹幕/缓冲不震；无硬件或关闭时 UI 仍完整（interaction §6.4）。
7. **自适应而非「假原生」**：统一 Liquid Glass + 自有 token；尊重各 OS 滚动条、菜单、窗口控制。
8. **性能分级**：默认 `GlassQuality.standard`；静态栏可 `premium`（Impeller）；列表禁用重玻璃。
9. **无障碍默认**：对比度、焦点环、Semantics；icon-only 必有名称；Reduce Motion / Transparency 尊重。
10. **本地化内建**：文案不硬编码；布局预留扩展；数字/时间走 locale。
11. **文案清晰有用**：清楚、简练、可行动；见 [copy.md](./copy.md)。

---

## 4. 与架构文档的边界

| 关注点 | 归属 |
|--------|------|
| 主题 token、玻璃、**图标策略**、组件视觉、动效时长 | `docs/ux/*` |
| **触觉语义与场景**、快捷键、导航/播放器操作 | [interaction.md](./interaction.md) |
| 界面用词、Tooltip/Semantics 措辞 | [copy.md](./copy.md) |
| 路由、Riverpod、`core/haptics` / `core/icons` 目录 | [design/flutter.md](../design/flutter.md) |
| 播放地址、清晰度逻辑 | Rust `media` + API |
| Cookie / 签名 | Rust `auth` / `http`，UI 不可见 |
| 非敏感偏好（含触感开关） | 主题可 Flutter 本地；其余见 [design/store.md](../design/store.md) |

---

## 5. 已锁定决策（速查）

| 决策 | 值 |
|------|-----|
| 视觉语言 | Liquid Glass（内容不透明 + chrome 玻璃） |
| 实现库 | `liquid_glass_widgets` `^0.22.1` |
| 默认玻璃质量 | `GlassQuality.standard` + `adaptiveQuality: true` |
| 玻璃用 / 不用 | chrome·浮层用；Feed/评论/画面不用（design-system §2.5） |
| 手机 / 折叠 | P2；Fold / Flip 同断点（multi-platform） |
| **配色 accent** | Light `#0284C7` / Dark `#38BDF8`（Sky；**非** B 站粉） |
| 深色 / 浅色画布 | `#0B0F1A` / `#F4F6FA` |
| **字体** | Inter + 系统 CJK fallback |
| **图标集** | Lucide（Outlined）；业务 `AppIcons.*` |
| **图标形态** | 导航展开=图标+文字；icon-only 仅通用/紧凑 chrome；CTA 必有文字（§7） |
| **触觉** | 语义 token（`haptic.*`）；默认触摸开、纯指针桌面关；可关、可 no-op |
| **UI 底座** | 自有语义 Token；**不用 Material 3 视觉** |
| Flutter 下限 | ≥ 3.41.0 |

细节：视觉/图标 → [design-system](./design-system.md)；触觉/操作 → [interaction](./interaction.md)。

---

## 6. 版本与变更

- 文档版本与 `architecture.md` 同步用草案号（当前 UX **v0.4**）。
- 变更影响实现时：先改本文与对应专章，PR 标明破坏性（token 改名、断点、换库、图标/触觉策略）。
- Token 命名以 **语义** 为准（`color.bg.canvas`、`glass.blur`、`haptic.selection`），实现映射到 Theme / Haptics / AppIcons。

| 版本 | 说明 |
|------|------|
| v0.1 | 初稿：M3 主路径 |
| v0.2 | 确立 Liquid Glass；锁定配色与 `liquid_glass_widgets` |
| v0.3 | 锁定 Sky accent / Inter / Lucide；明确不用 M3 与 B 站粉 |
| v0.4 | 增补图标用/不用 + 触觉反馈；原则/锁定表/反馈通道索引 |
