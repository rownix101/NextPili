# HTTP 层设计（`http`）

> 状态：草案  
> 依赖：`domain`、`auth`  
> 端点契约：[api/](../api/README.md)

---

## 1. 职责

- 持有 `reqwest::Client`（连接池、代理、超时、压缩）。
- 请求中间件：账号 Cookie、csrf、WBI、AppSign、通用 Header。
- 按业务拆分 endpoint 模块，反序列化 raw JSON → 转 domain。
- 统一 `BiliResponse` 与错误映射。

---

## 2. 客户端栈

```text
Endpoint method
    │
    ▼
RequestBuilder
    │  path / query / form / json
    ▼
Middleware pipeline (顺序固定)
    1. resolve AccountSlot → Account
    2. attach Cookie | access_key
    3. attach baseline headers (Referer, UA, x-bili-*)
    4. WBI sign if flagged
    5. AppSign if flagged
    6. csrf if Web POST flagged
    ▼
reqwest send
    ▼
decode BiliResponse / raw bytes / protobuf
    ▼
map code → domain::Error
    ▼
into domain model
```

### 2.1 客户端配置

| 项 | 建议默认 |
|----|----------|
| timeout | 20s |
| connect_timeout | 10s |
| redirect | 有限次数 |
| gzip / brotli | 开启 |
| http2 | 开启（reqwest 默认能力） |
| proxy | 系统 + 用户覆盖 |
| cookie_store | 按请求从 Account jar 注入（多账号不能共用全局 jar） |

**多账号**：不要用单一全局 `reqwest` cookie_store 自动管理所有域账号；改为每次从 `Account.cookie_jar` **显式**写 `Cookie` 头，响应 `Set-Cookie` 写回该账号 jar。

---

## 3. 请求元数据

```rust
struct RequestSpec {
    url: UrlKind,          // RelativeApi("/x/...") | Absolute(Url)
    method: Method,
    slot: AccountSlot,     // 或 ApiKind → slot
    auth: AuthMode,        // Cookie | App | OptionalLogin | None
    sign: SignMode,        // None | Wbi | AppSign
    csrf: bool,
    content: BodyKind,     // Query | Form | Json | Bytes
}
```

相对路径默认 `https://api.bilibili.com`。  
其它域名见 [overview 域名表](../api/auth/overview.md)。

---

## 4. 响应

```json
{ "code": 0, "message": "0", "ttl": 1, "data": {} }
```

- 成功：`code == 0`，载荷在 `data`；部分 PGC 在 `result`。
- 封装：

```rust
struct BiliResponse<T> {
    code: i32,
    message: String,
    data: Option<T>,
    // 或 flatten 处理 result
}
```

二进制端点（部分弹幕）：不走 JSON，直接 bytes → `proto` / 自定义解析。

---

## 5. 模块划分

```text
http/
  src/
    lib.rs
    client.rs          # BiliClient, pipeline
    response.rs
    error_map.rs
    endpoints/
      mod.rs
      login.rs
      video.rs
      feed.rs
      reply.rs
      danmaku.rs
      search.rs
      user.rs
      ...
    raw/               # 可选：与 JSON 1:1 的 serde 结构
      video.rs
```

规则：

- `endpoints/*` 每个文件对应 `docs/api/endpoints/*.md` 一组。
- raw 结构允许脏字段；**不要**把 raw 暴露给 Flutter。
- 单文件过长时按读/写或子域再拆（如 `video_playurl.rs`）。

---

## 6. 重试与节流

| 情况 | 策略 |
|------|------|
| 传输层失败 | 幂等 GET：最多 2 次指数退避；POST 默认不重试 |
| -509 | 不自动狂重试；返回 `RateLimited` |
| -412 | 不重试；返回 `RiskControl` |
| -111 csrf | 可尝试刷新 cookie 一次，仍失败则 `Csrf` |
| WBI 签名错误类 | 强制 refresh mixinKey 一次后重试 |

---

## 7. 日志与脱敏

`tracing` span：`method`、`host`、`path`、`bili_code`、`latency`。  

脱敏：

- Header `Cookie`：只打「有/无」或 mid。
- Query：`sign`、`access_key`、`w_rid` 打码。
- 响应 body：debug 级别可截断；info 默认不打 body。

---

## 8. gRPC / 直播 WS（后续）

契约见 [api/auth/grpc.md](../api/auth/grpc.md)、[api/endpoints/live.md](../api/endpoints/live.md#弹幕-websocket-协议)。

- crate `proto` 放生成代码；帧编解码可放 `http` 或独立 `grpc` 模块。
- 客户端可单独 `GrpcClient`，鉴权 header 与 HTTP 共用 Account（`access_key` + bin metadata）。
- 直播弹幕：独立 `LiveWsClient`（16B 包头 + zlib/brotli），不走 REST middleware。
- 首期评论/弹幕优先 HTTP/`seg.so`；gRPC 用于翻译、分段弹幕对齐、完整 IM。

---

## 9. 测试

- `wiremock`：固定 status + body fixture（可从真实响应脱敏后入库 `tests/fixtures/`）。
- 中间件单测：不发网络，检查 `RequestSpec` 应用后的 URL/query/header。
- 契约测与 `docs/api` 同步：接口变更先改文档再改 fixture。

---

## 10. 代理与调试

```text
RuntimeConfig.proxy: Option<String>
// 或 HTTP_PROXY / HTTPS_PROXY
```

开发期可加 `RUST_LOG=http=debug`。  
抓包：系统代理指向 mitmproxy；注意证书信任在 reqwest 的配置（仅开发文档说明）。
