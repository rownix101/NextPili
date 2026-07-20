# FFI 设计（Flutter ↔ Rust）

> 状态：草案 · 对应 ADR-002  
> Crate：`core` 对外导出 · Flutter：`app/lib/bridge/`

---

## 1. 选型

| 方案 | 结论 |
|------|------|
| **flutter_rust_bridge** | 默认；async Future / Stream、代码生成 |
| 手写 C ABI | 否（维护成本高） |
| localhost JSON-RPC | 仅调试备选，不作默认 |

目标 FRB 模式：Rust 定义 API → codegen → Dart 调用。  
同步相关：`flutter_rust_bridge` 版本与 `cargokit`/构建脚本固定在仓库文档中。

---

## 2. 生命周期

```text
Flutter main()
  → RustLib.init()          # 加载动态库、启动 runtime
  → core.bootstrap(paths)   # 数据目录、日志、加载账号
  → runApp(...)
  → (运行中) API / Stream
  → 退出：dispose / 落盘
```

`bootstrap` 参数（示例）：

| 字段 | 说明 |
|------|------|
| `data_dir` | 应用数据根（账号、sqlite） |
| `cache_dir` | 可清理缓存 |
| `log_level` | tracing 级别 |
| `proxy` | 可选覆盖，如 `http://127.0.0.1:7890` |

幂等：重复 `bootstrap` 应安全（已初始化则更新可热更新配置项，或返回 `already_initialized`）。

---

## 3. API 面设计原则

1. **面向用例**，不暴露 raw path / 签名细节。  
2. **输入输出均为 DTO**（可序列化、无生命周期引用）。  
3. **一个调用 = 一次用户意图**（可在 Rust 内聚合多次 HTTP）。  
4. **长任务用 Stream 或分步 Future**，避免超长单 Future 无进度。  
5. **不传 Cookie 明文给 Flutter**（导入 Cookie 时一次性字符串入参，之后只存 Rust）。

### 3.1 命名

| 侧 | 风格 |
|----|------|
| Rust 函数 | `snake_case`：`video_detail`、`feed_recommend` |
| Dart 生成 | 随 FRB；封装层可用 `CoreApi.videoDetail` |
| 类型 | Rust `PascalCase`；Dart 同名生成 |

### 3.2 模块分组（逻辑，非强制多类）

```text
sys:       api_version, ping, bootstrap, set_proxy, shutdown
auth:      login_sms_*, login_password, login_qr_* (desktop/tablet UI), logout, list_accounts, set_slot
feed:      feed_recommend, feed_popular
video:     video_detail, play_url, video_related
social:    reply_list, reply_add, danmaku_segments, danmaku_post
user:      history_list, toview_list, fav_folders, fav_resources
search:    search_video, search_suggest
dynamics:  dynamics_feed
live:      live_recommend, live_room, live_play_url, live_dm_history, live_send_msg
pgc:       pgc_rank, pgc_season, pgc_play_url
engagement: video_relation, video_like, video_coin, video_favorite, relation_follow
```

P0 仅需 `sys` + 占位；P1 起按 MVP 表增加。

---

## 4. 类型约定

| 概念 | Rust | Dart | 备注 |
|------|------|------|------|
| 视频 BV | `String` 或 newtype 映射为 String | `String` | 边界用 string，内部 domain 用 newtype |
| aid/cid/mid | `i64` | `int` | B 站 ID 可能超过 32 位 |
| 时间 | `i64` **毫秒** Unix | `int` | 全文统一毫秒 |
| 可选 | `Option<T>` | `T?` | |
| 列表 | `Vec<T>` | `List<T>` | |
| 枚举 | `enum` | 生成 enum | 未知变体需可演进策略 |
| 错误 | 见 §5 | 异常 / Result 封装 | |

**枚举演进**：对外枚举增加变体视为次要兼容；删除/改名升 `api_version` major。  
未知服务端枚举：落为 `Unknown(raw: i32/String)` 或保留 raw 字段，避免反序列化失败导致整页挂掉。

### 4.1 代表性 DTO（示意）

```rust
// 非最终代码，仅约定形状

pub struct VideoDetailDto {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub desc: String,
    pub owner_mid: i64,
    pub owner_name: String,
    pub pages: Vec<VideoPageDto>,
    pub stat: VideoStatDto,
    pub duration_ms: i64,
}

pub struct MediaSourceDto {
    pub cid: i64,
    pub format: MediaFormat, // Dash | Segment
    pub videos: Vec<StreamDto>,
    pub audios: Vec<StreamDto>,
    pub recommended_video_id: String,
    pub recommended_audio_id: String,
    pub headers: Vec<(String, String)>, // 播放请求可能需要的 Referer 等
    pub subtitles: Vec<SubtitleTrackDto>,
}

pub struct FeedItemDto {
    pub bvid: String,
    pub aid: i64,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: i64,
    pub goto: String, // 已过滤时多为 av
}
```

---

## 5. 错误模型

### 5.1 Rust

```rust
pub struct AppError {
    pub kind: ErrorKind,
    pub message: String,
    /// B 站业务 code，非 B 站错误为 None
    pub bili_code: Option<i32>,
}

pub enum ErrorKind {
    Unauthenticated,  // -101
    Csrf,             // -111
    RiskControl,      // -412
    NotFound,         // -404
    RateLimited,      // -509
    InvalidArgument,
    Network,
    Parse,
    Storage,
    Internal,
}
```

映射规则（摘要）：

| 来源 | kind |
|------|------|
| HTTP 传输失败 / 超时 | `Network` |
| JSON / 字段缺失 | `Parse` |
| `code == -101` | `Unauthenticated` |
| `code == -111` | `Csrf` |
| `code == -412` | `RiskControl` |
| `code == -404` | `NotFound` |
| `code == -509` | `RateLimited` |
| 其它 `code != 0` | `Internal` 或后续细分子码，`message` 用服务端文案 |
| sqlite / 密钥环 | `Storage` |

`message`：**可展示给用户的中文或原文**；调试细节走 `tracing`，不塞进 message。

### 5.2 Flutter

```dart
// 封装示例
class AppException implements Exception {
  final ErrorKind kind;
  final String message;
  final int? biliCode;
}
```

UI 策略：

| kind | 行为 |
|------|------|
| `unauthenticated` | 全局跳转登录 / 清会话横幅 |
| `risk_control` | 专用提示，勿死循环重试 |
| `rate_limited` | 退避后重试 |
| `network` | Snackbar + 重试按钮 |
| 其它 | 通用错误组件 |

---

## 6. 事件流（Stream）

适合推送、不宜轮询的状态：

| 事件 | 载荷 | 用途 |
|------|------|------|
| `AuthEvent` | 登录成功 / 失效 / 账号切换 | 刷新全局会话 |
| `QrLoginEvent` | 二维码 URL、扫码中、确认、过期 | 登录页 |
| `PlaybackHeartbeat`（可选） | 可选 ack | 调试；实际上报在 Rust 内完成 |
| `AccountRisk` | mid、原因 | 提示某槽位账号异常 |

约定：

- Stream 在 `bootstrap` 后可订阅；热启动重订阅不丢「当前快照」——提供 `auth_state()` 查询 + 事件增量。
- 高频事件（如播放进度）**不要**过 FFI Stream；播放进度留在 Flutter 播放器。

---

## 7. 并发与线程

- Rust：`tokio` 多线程；HTTP 全 async。
- FRB 调用默认不阻塞 UI isolate。
- 共享状态（`AccountRegistry`、HTTP 客户端）用 `Arc<RwLock<_>>` 或 actor 模式；**避免**在持锁时做 HTTP。
- 取消：P1 起为长请求预留 `cancel_token` / FRB 取消支持；未实现前超时必须配置（默认 15–30s）。

---

## 8. 版本与兼容

```rust
pub struct ApiVersion {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
    pub core: String, // git hash 或 semver 包版本
}
```

- Flutter 启动：`api_version()`，major 不匹配则拒绝运行并提示升级。
- **major**：删字段、改语义、删 API。  
- **minor**：新增 API / 可选字段。  
- **patch**：修复。

---

## 9. 安全边界

| 允许进入 Flutter | 禁止进入 Flutter 持久化 |
|------------------|-------------------------|
| mid、昵称、头像 URL | `SESSDATA`、`bili_jct` |
| 登录是否有效 | `access_key` |
| 导入 Cookie 的**一次性**入参 | 任何 Cookie 回读 API（默认不做 export；若做需二次确认） |

日志：Rust 侧打印 URL 时可保留 path，**query 中 sign/cookie 脱敏**。

---

## 10. 测试

- Rust：`core` 集成测 mock `http`，不加载 Flutter。
- Dart：对 `bridge` 做 `FakeCoreApi` 接口，feature 测不碰真实动态库。
- 可选：一件式 `flutter test` + 编译好的 stub lib（后期）。

---

## 11. P0 最小 API

```text
ping() -> String
api_version() -> ApiVersion
bootstrap(BootstrapConfig) -> ()
```

打通即 P0 完成，再叠 auth。
