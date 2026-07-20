# `domain` 领域层设计

> 状态：草案  
> 约束：**无 IO**（无 reqwest、无 std::fs、无数据库）

---

## 1. 目标

- 集中业务概念与不变量。
- 错误类型与映射表的「语义层」。
- 供 `http` 反序列化之后、`core` 出 FFI 之前使用的中间模型。

---

## 2. 标识与值对象

```text
VideoId     = Bvid(String) | Aid(i64)    // 解析："BV..." / 纯数字
Cid         = i64
UserMid     = i64
AccountId   = 本地 UUID 或 mid 字符串（本地主键策略见 store）
QualityQn   = u32                         // B 站 qn
DurationMs  = i64
```

### 2.1 VideoId 解析规则

| 输入 | 结果 |
|------|------|
| `BV1...`（合法前缀） | `Bvid` |
| 纯数字 | `Aid` |
| `av123` | 去前缀 → `Aid` |
| 空/乱码 | `Error::InvalidArgument` |

播放与详情 API 按 variant 填 `bvid` 或 `aid` 参数（见 api 文档）。

### 2.2 不变量（示例）

- `Cid > 0`（校验在构造函数 / `TryFrom`）。
- `UserMid > 0` 表示已登录用户；`0` 仅作「未登录占位」若需要。

优先 **try 构造** 而非公开可变字段。

---

## 3. 核心实体（逻辑模型）

不必与 JSON 1:1；只保留产品需要的字段。

```text
AccountPublic
  id, mid, name, avatar_url, is_login

VideoDetail
  aid, bvid, title, cover, desc, owner, pages[], stat, duration_ms, ...

VideoPage
  cid, page, part, duration_ms

FeedItem
  aid, bvid, title, cover, owner_name, duration_ms, goto

Reply
  rpid, mid, content, ctime_ms, like, children_count, ...

DanmakuItem
  progress_ms, mode, fontsize, color, text, mid_hash, ...

MediaSource   # 也可放 media crate，但形状由 domain 定义 trait 或 struct
  ...
```

`MediaSource` 若依赖播放器细节过多，结构体放 `media`，domain 只放 `Quality` 选择策略等纯函数。

---

## 4. 错误

```rust
pub enum Error {
    InvalidArgument { msg: String },
    Unauthenticated,
    Csrf,
    RiskControl { message: String },
    NotFound,
    RateLimited,
    Api { code: i32, message: String },
    // 下列由上层 map，domain 可不直接构造 Network/Storage
}
```

### 4.1 从 B 站 `code` 映射

| code | Error |
|------|-------|
| 0 | 成功 |
| -101 | `Unauthenticated` |
| -111 | `Csrf` |
| -404 | `NotFound` |
| -412 | `RiskControl` |
| -509 | `RateLimited` |
| 其它非 0 | `Api { code, message }` |

纯函数：`fn map_bili_code(code: i32, message: &str) -> Result<(), Error>`。

`core` 再把 `Error` → `AppError`（含 Network/Parse/Storage）。

---

## 5. 端口（trait）

仅当需要可测替换时定义，避免为抽象而抽象。

```text
// 示例，实现放 store
trait AccountRepository {
    fn list(&self) -> Result<Vec<AccountPublic>, Error>;
    fn save_secrets(&self, ...) -> Result<(), Error>;
    ...
}
```

HTTP 不一定强行 `trait`；可用 `wiremock` 打真实客户端。若 `core` 要单测用例，可对 `VideoApi` 抽小 trait。

---

## 6. 纯策略函数（示例）

放 domain 便于单测：

| 函数 | 作用 |
|------|------|
| `filter_feed_item(goto, blacklists)` | 推荐过滤 |
| `pick_quality(available, preferred, max)` | 默认清晰度 |
| `pick_audio_track(tracks, lang_pref)` | 音轨 |
| `parse_video_id(&str)` | ID 解析 |

---

## 7. 模块文件建议

```text
domain/
  src/
    lib.rs
    id.rs          # VideoId, Cid, ...
    error.rs
    account.rs
    video.rs
    feed.rs
    reply.rs
    danmaku.rs
    quality.rs
```

保持文件按概念切，单文件避免无限变长。

---

## 8. 依赖白名单

允许：`serde`（若 DTO 复用）、`thiserror`、`uuid`（若 AccountId 需要）。  
禁止：`reqwest`、`tokio`、`rusqlite`、`flutter_*`。

serde：更推荐 **http 层 raw 类型** 与 **domain 手写 From**，避免 domain 被 API 噪声污染；若图省事可限 `serde` 仅用于稳定内部格式。
