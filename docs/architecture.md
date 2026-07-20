# NextPili 架构文档

> 状态：草案 v0.2 
> 技术选型：**Rust（核心） + Flutter（UI）** 
> 相关：
> - [Bilibili API](./api/README.md)
> - [设计索引](./design/README.md)
> - [UX 索引](./ux/README.md)

本文档描述系统分层、模块边界与关键决策。 
API 契约见 `docs/api/`；模块级细节见 `docs/design/`。

---

## 1. 目标与非目标

### 1.1 产品目标

- 桌面端优先的 B 站第三方客户端（Linux / Windows / macOS；移动端后续可选）。
- 常用路径：登录、推荐/热门、播放、弹幕/评论、搜索、历史/收藏、动态、直播、番剧。
- 核心业务与协议可独立测试，不绑死某一 UI 框架。

### 1.2 工程目标

| 目标 | 说明 |
|------|------|
| 协议集中 | Cookie / CSRF / WBI / AppSign / buvid / 多账号路由 **全部在 Rust** |
| UI 轻薄 | Flutter 只做展示与交互；不实现 B 站签名与业务拼装 |
| 可测试 | 域逻辑可无 Flutter 单测；关键路径可 mock HTTP |
| 可演进 | 播放器、gRPC、缓存策略可替换 |
| 安全边界 | 凭据不出 Rust 持久化层；Flutter 不落明文 Cookie |

### 1.3 非目标（当前阶段）

- 不实现服务端中继 / 自建 API 代理（直连 B 站）。
- 不做插件市场 / 用户脚本运行时。
- 不保证与官方客户端 100% 行为一致（以 `docs/api` + 实测为准）。
- 首期不做完整消息/商城等长尾业务。

---

## 2. 总体架构

```text
┌──────────────────────────────────────────────────────────────────┐
│ Flutter (UI Shell) │
│ pages / widgets / Liquid Glass chrome / theme / router │
│ Riverpod ←→ generated FFI bindings · 非凭据本地偏好 │
└───────────────────────────────┬──────────────────────────────────┘
 │ flutter_rust_bridge (async API)
 │ 类型安全 · 错误映射 · Stream 事件
┌───────────────────────────────▼──────────────────────────────────┐
│ core (Rust workspace 门面) │
│ │
│ ┌─────────────┐ ┌──────────────┐ ┌─────────────────────────┐ │
│ │ app / api │ │ domain │ │ infrastructure │ │
│ │ 用例编排 │→ │ 模型·错误 │← │ http · auth · store │ │
│ │ Session │ │ 仓储接口 │ │ media · proto │ │
│ └─────────────┘ └──────────────┘ └─────────────────────────┘ │
│ │
│ 对外：高层命令（登录、拉推荐、取播放地址…）+ 事件流 │
└───────────────────────────────┬──────────────────────────────────┘
 │ HTTPS / gRPC
 ▼
 bilibili.com / live / passport …
```

**一句话**：Flutter 是壳，Rust 是脑；网络、鉴权、会话、业务编排与凭据持久化都在 Rust。

---

## 3. 仓库布局（目标）

```text
NextPili/
├── docs/
│ ├── api/ # B 站 HTTP/gRPC 约定
│ ├── design/ # 模块级设计（工程）
│ ├── ux/ # 设计规范 / 交互 / 动效 / 多平台 / 本地化
│ └── architecture.md # 本文
├── crates/ # Rust workspace
│ ├── core/ # FFI 入口 + 应用服务编排
│ ├── domain/ # 纯领域：模型、错误、仓储 trait（无 IO）
│ ├── http/ # HTTP 客户端、签名中间件、端点实现
│ ├── auth/ # Cookie jar、账号、WBI、AppSign、buvid
│ ├── store/ # 本地持久化（账号、设置、缓存元数据）
│ ├── media/ # 播放地址规范化、清晰度/音轨、弹幕时间轴
│ └── proto/ # （可选）gRPC / protobuf 生成物
├── app/ # Flutter 工程
│ ├── lib/
│ │ ├── main.dart
│ │ ├── bridge/ # FRB 生成代码 + 薄封装
│ │ ├── features/ # home / player / search / …
│ │ ├── shared/ # 主题、路由、动效、自适应、通用组件
│ │ └── app.dart
│ └── pubspec.yaml
├── Cargo.toml # workspace root
└── README.md
```

原则：

- **按职责拆 crate**，目录名即 crate 名（`core`、`domain`…），不加项目前缀。
- package 名在 `Cargo.toml` 中可与目录一致；若 crates.io 冲突仅影响发布，本地 path 依赖不受影响。
- Flutter `features/*` 按用户可见功能切分。
- 生成代码（FRB、protobuf）单独目录，禁止手改。

---

## 4. 分层职责

### 4.1 Flutter（表现层）

**负责**：路由、布局、**Liquid Glass chrome**（`liquid_glass_widgets`）、主题 token、播放器控件 UI、展示用图片缓存、非敏感本地偏好。 
**不负责**：WBI/AppSign/csrf、解析 B 站原始业务 JSON、Cookie/`access_key` 读写。

视觉与材质 token：[ux/design-system.md](./ux/design-system.md)。 
工程结构：[design/flutter.md](./design/flutter.md)。

### 4.2 `core`（应用层）

- 面向用例的稳定 API（给 FRB）：登录、推荐、详情、playurl、评论、弹幕、搜索…
- 编排 domain + http + auth + store + media。
- 注入会话 / 账号上下文；映射错误为 FFI 友好结构。

详见 [design/ffi.md](./design/ffi.md)、[design/core.md](./design/core.md)。

### 4.3 `domain`（领域层）

- 值对象：`VideoId`、`Cid`、`UserMid`、`Quality`、`AccountId`…
- 统一错误、仓储 trait。
- **无** reqwest / 文件系统 / Flutter 依赖。

详见 [design/domain.md](./design/domain.md)。

### 4.4 `http` + `auth`（基础设施）

与 [api/auth/overview.md](./api/auth/overview.md) 对齐：选账号 → Cookie/`access_key` → WBI 或 AppSign → csrf → reqwest → 统一解析。

详见 [design/http.md](./design/http.md)、[design/auth.md](./design/auth.md)。

### 4.5 `store`

账号凭据（加密/keyring）、多账号映射、播放进度、设置。 
详见 [design/store.md](./design/store.md)。

### 4.6 `media`

playurl → `MediaSource`；弹幕分段 → 时间轴事件。不内嵌播放器内核。 
详见 [design/media.md](./design/media.md)。

---

## 5. 跨语言边界（摘要）

| 项 | 决策 |
|----|------|
| 方案 | **flutter_rust_bridge**（默认） |
| 风格 | 异步方法 + Stream 事件 |
| 错误 | `AppError { kind, message, bili_code? }` → Flutter sealed/Exception |
| 线程 | tokio；禁止 FFI 同步回调里阻塞 HTTP |

完整约定：[design/ffi.md](./design/ffi.md)。

---

## 6. 账号与会话（摘要）

| AccountSlot | 用途 |
|-------------|------|
| `main` | 写操作默认 |
| `heartbeat` | 心跳 / 历史上报 |
| `recommend` | 推荐、热门、搜索 |
| `video` | 播放地址 |

单账号时四槽指向同一账户。详见 [design/auth.md](./design/auth.md)。

---

## 7. 媒体播放（摘要）

```text
Flutter → core.play_url → MediaSource → media_kit 适配层 → Surface
```

Rust 只出资源描述；播放器可替换。详见 [design/media.md](./design/media.md)。

---

## 8. 关键数据流

### 打开视频并播放

```text
1. UI 点击稿件 (bvid)
2. Flutter → core.video_detail(bvid)
3. Rust: WBI detail → DTO
4. Flutter → core.play_url(bvid, cid, qn?)
5. Rust: video 槽 → DASH → MediaSource
6. Flutter PlayerAdapter.play(MediaSource)
7. Rust: heartbeat 槽上报；danmaku → Overlay
```

### 推荐刷新

```text
UI 下拉 → core.feed_recommend(fresh_idx, ps)
 → recommend 槽 + WBI → 过滤 → Vec<FeedItem>
```

---

## 9. 配置与构建

| 项 | 建议 |
|----|------|
| Rust | Edition 2021+，workspace，CI clippy |
| Flutter | 稳定 channel；桌面三端；**≥ 3.41**（`liquid_glass_widgets`） |
| FFI | FRB codegen；CI 检查生成物 diff（或生成脚本） |
| 密钥 | 公开客户端常量集中配置；用户 Cookie 永不进仓库 |
| 日志 | Rust `tracing`（脱敏）；开发期 Flutter `debugPrint` |
| 代理 | 系统代理 + 用户覆盖，统一在 HTTP 客户端 |

---

## 10. 测试策略

| 层级 | 内容 |
|------|------|
| Domain | ID 解析、错误映射、清晰度纯函数 |
| Auth | WBI/AppSign 向量、csrf 注入 |
| HTTP | wiremock + fixture |
| FFI 烟测 | `api_version` / 未登录错误形态 |
| Flutter | widget + fake bridge |
| 手工 E2E | 扫码 → 推荐 → 播放 → 弹幕 |

CI **禁止**真实用户 Cookie。

---

## 11. 安全与隐私

- Cookie / `access_key` 仅存 Rust 存储后端。
- 日志剥离 `SESSDATA`、`bili_jct`。
- 不提供绕过风控/会员的实现指导。

---

## 12. MVP 落地顺序

| 阶段 | 交付 |
|------|------|
| **P0** | workspace + Flutter + FRB `ping` / `api_version` |
| **P1** | Cookie jar、buvid、WBI、AppSign、扫码登录、会话持久化 |
| **P2** | 推荐/热门、视频详情 |
| **P3** | playurl、media_kit、清晰度切换 |
| **P4** | 评论列表、弹幕展示 |
| **P5** | 搜索、历史、稍后再看、收藏只读 |
| **P6** | 动态、直播、番剧、多账号槽、写操作 |

结束标准：Rust 单测绿 + 桌面可演示 + API 偏差回写 `docs/api`。  
**分阶段验收、依赖与横切能力**见 [roadmap.md](./roadmap.md)（当前：**P6 进行中** · 动态 + 直播 REST + 番剧可播已交付）。

---

## 13. 架构决策记录（ADR）

### ADR-001：Rust 承载全部 B 站协议

- **原因**：与 `docs/api` 边界一致；单测友好；避免 Dart/Rust 双份签名。
- **后果**：改协议需经 FFI；维护 FRB 工具链。

### ADR-002：flutter_rust_bridge 作为默认 FFI

- **原因**：类型安全、async/Stream 成熟。
- **后果**：依赖 codegen；升级需回归。

### ADR-003：播放器与协议解耦

- **原因**：播放器插件迭代快。
- **后果**：`MediaSource` 适配层；换播放器不改业务。

### ADR-004：多账号按槽位路由

- **原因**：隔离推荐污染与播放/历史上报（多账号实践验证）。
- **后果**：存储与 UI 支持槽位配置；单账号退化为同一账户。

### ADR-005：领域层无 IO

- **原因**：核心规则可单测。
- **后果**：多 crate 样板略增。

### ADR-006：crate 命名不加项目前缀

- **决策**：`core` / `domain` / `http` / `auth` / `store` / `media` / `proto`。
- **原因**：仓库即上下文，短名更清晰；path 依赖不受 crates.io 占用影响。

---

## 14. 风险与开放问题

| 风险 | 缓解 |
|------|------|
| 接口/WBI 变更 | 契约测试 + `docs/api` 回写 |
| -412 风控 | 完整 UA/buvid/代理；多账号；退避 |
| FRB 桌面构建 | P0 先打通最小链路 |
| 弹幕性能 | 分页、限流、Rust 预处理 |

开放问题：

1. 设置项是否 100% 走 Rust store？ → 见 [design/store.md](./design/store.md) 建议。
2. gRPC（评论翻译/弹幕）是否进入 P4？ → 默认 P4 HTTP，gRPC 随后。
3. 发行与自动更新（非架构阻塞）。

---

## 15. 文档维护

入口与写法：[docs/README.md](./README.md) · [Documentation Style Pathway](./writing.md)

| 变更 | 位置 |
|------|------|
| 端点 / 签名 | `docs/api/**` |
| 分层、ADR、边界 | 本文 |
| 模块细节 | `docs/design/*` |
| 视觉 / 交互 | `docs/ux/*` |
| 文档结构与语气 | `docs/writing.md` |

---

## 附录 A：crate 依赖方向

```text
core → domain, http, auth, store, media
http → domain, auth
media → domain
auth → domain
store → domain
domain → （仅 std + 轻量纯计算）
proto → （生成代码；被 http/media 按需依赖）
```

禁止：`domain` → `http`/`store`；Flutter 直接做 B 站签名/业务 HTTP。

## 附录 B：文档映射

| 概念 | 文档 |
|------|------|
| 域名 / Cookie / 多账号 | [api/auth/overview.md](./api/auth/overview.md) |
| WBI / AppSign | [api/auth/wbi.md](./api/auth/wbi.md)、[app-sign.md](./api/auth/app-sign.md) |
| 端点与 MVP | [api/README.md](./api/README.md) |
| FFI / 鉴权 / HTTP / 媒体 / 存储 / 领域 / Flutter | [design/](./design/README.md) |
| 视觉 Liquid Glass / 交互 / 动效 / 多平台 / 本地化 | [ux/](./ux/README.md) · [design-system](./ux/design-system.md) |
