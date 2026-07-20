# 鉴权与请求基础设施

域名、通用响应、Cookie、Headers 与多账号槽位路由。

## 域名

| 常量 | URL | 用途 |
|------|-----|------|
| `baseUrl` | `https://www.bilibili.com` | Referer / 页面源 |
| `apiBaseUrl` | `https://api.bilibili.com` | **默认 API**（相对路径拼这里） |
| `appBaseUrl` | `https://app.bilibili.com` | App 接口 |
| `passBaseUrl` | `https://passport.bilibili.com` | 登录 / 鉴权 |
| `liveBaseUrl` | `https://api.live.bilibili.com` | 直播 |
| `tUrl` | `https://api.vc.bilibili.com` | 动态旧接口 / 私信 session |
| `messageBaseUrl` | `https://message.bilibili.com` | 系统通知 |
| `accountBaseUrl` | `https://account.bilibili.com` | 账户（硬币数等） |
| `spaceBaseUrl` | `https://space.bilibili.com` | 空间页 / 举报 |
| `dynamicShareBaseUrl` | `https://t.bilibili.com` | 动态分享页 |
| `mallBaseUrl` | `https://mall.bilibili.com` | 商城小店 |
| search | `https://s.search.bilibili.com` | 热搜 / 搜索建议 |
| SponsorBlock | `https://www.bsbsb.top` | 第三方跳过片段（可选） |

相对路径（以 `/` 开头）→ 默认 `https://api.bilibili.com{path}`。 
绝对 URL（含 `https://`）→ 直接使用。

## 通用响应

```json
{
 "code": 0,
 "message": "0",
 "ttl": 1,
 "data": {}
}
```

| 字段 | 说明 |
|------|------|
| `code` | `0` 成功；非 0 失败 |
| `message` / `msg` | 错误信息 |
| `data` | 成功载荷（多数接口） |
| `result` | 部分 PGC 接口用 `result` 代替 `data` |

常见错误码（节选）：

| code | 含义 |
|------|------|
| 0 | 成功 |
| -101 | 未登录 / 账号失效 |
| -111 | csrf 校验失败 |
| -400 | 请求错误 |
| -403 | 权限不足 |
| -404 | 不存在 |
| -412 | 请求被拦截（风控 / 签名 / UA） |
| -509 | 请求过于频繁 |

## Cookie

### 关键 Cookie

| Cookie | 作用 |
|--------|------|
| `SESSDATA` | 登录会话（HttpOnly 风格，Web 必需） |
| `bili_jct` | CSRF Token；POST 时作为 `csrf` |
| `DedeUserID` | 用户 mid |
| `DedeUserID__ckMd5` | mid 校验 |
| `sid` | 会话 id |
| `buvid3` | 设备/浏览器标识（未登录也要有） |
| `buvid4` | 新版设备标识（部分场景） |
| `b_nut` | buvid 相关 |

Cookie 域：`.bilibili.com`，path `/`。

### CSRF

```text
csrf = cookie["bili_jct"]
```

Web POST 表单几乎都要带：

```text
csrf=<bili_jct>
```

部分接口字段名为 `biliCSRF` 或同时要 `csrf_token`。

### buvid3 生成

未登录也会生成并写入 cookie jar，用于风控与推荐。

格式参考：`{UUID大写前段}{时间相关}infoc`。  
另可通过 `POST /x/internal/gaia-gateway/ExClimbWuzhi` 上报 payload 激活 buvid。

## Headers

### Web 基线（登录账号）

```http
env: prod
app-key: android64
x-bili-aurora-zone: sh001
x-bili-mid: <mid>
x-bili-aurora-eid: <由 mid 生成>
referer: https://www.bilibili.com
Cookie: <cookie jar>
```

### App 基线

对 `https://app.bilibili.com`：

- 不依赖 Cookie 管理；用 `access_key` + AppSign
- 拦截器会把 `access_key` 注入 query/body，并计算 `sign`
- 推荐/部分接口会带自定义 UA：

```text
Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android model/android_hd mobi_app/android_hd build/2001100 channel/master innerVer/2001100 osVer/15 network/2
```

统计字段：

```json
{"appId":5,"platform":3,"version":"2.0.1","abtest":""}
```

（HD 端；手机端另有 `8.43.0` / `appId:1` 组合）

### 关键 App 常量（Android HD）

| 字段 | 值 |
|------|-----|
| `appkey` | `dfca71928277209b` |
| `appsec` | `b5475a8825547a4fc26c7d518eaaa02e` |
| `mobi_app` | `android_hd` |
| `build` | `2001100` |
| `platform` | `android` |

> 注意：appkey/appsec 属于公开客户端常量，但仍应集中配置，避免散落硬编码。

## 多账号策略

按 **接口路径** 选择使用哪个账号槽位（`ApiKind` / 路径映射表）。

| AccountType | 用途 | 典型接口（常量名） |
|-------------|------|-------------------|
| `main` | 默认登录账号 | 点赞、收藏、发评、动态、关系…（未列入其它集合的） |
| `heartbeat` | 进度/历史上报与只读播放相关隔离 | `heartBeat`, `historyReport`, `videoIntro`, `replyList`, `pgcInfo`, `liveRoomInfo*`, `onlineTotal`, `aiConclusion`, `liveRoomDm*`, `superChatMsg`, `searchByType`, `ab2c`… |
| `recommend` | 推荐流 / 搜索 / 排行隔离 | `recommendList*`, `hotList`, `relatedList`, `hotSearchList`, `searchSuggest`, `searchTrending`, `getRankApi`, `pgcIndexResult`, `popular*`, `liveFeed*`, `liveSearch`… |
| `video` | 播放地址隔离 | `ugcUrl`, `pgcUrl`, `pugvUrl`, `tvPlayUrl`, `videoshot` |

登录专用路径（不走业务 Cookie 槽混用）：`getTVCode`, `qrcodePoll`, 密码/短信/safecenter/`oauth2AccessToken` 等（`ApiType.loginApi`）。

gRPC 路径映射可暂与 `main` 槽位对齐。

NextPili 若做多账号，建议同样按 path 路由；单账号可全部走 main。 
无痕/访客场景：仅 `heartbeat`/`video` 槽用空 Cookie，避免污染主号历史与推荐。

## 请求客户端建议（Rust）

```text
┌─────────────┐
│ API 调用层 │ 业务方法
└──────┬──────┘
 │
┌──────▼──────┐
│ 签名中间件 │ WBI / AppSign / csrf 注入
└──────┬──────┘
 │
┌──────▼──────┐
│ Cookie 中间件│ 读写 cookie jar，选账号
└──────┬──────┘
 │
┌──────▼──────┐
│ HTTP 客户端 │ reqwest / hyper + HTTP/2 可选
└─────────────┘
```

能力清单：

- [ ] Cookie 持久化 jar（按账号）
- [ ] 按 path 路由 `main` / `heartbeat` / `recommend` / `video`
- [ ] 自动附带 `referer`
- [ ] Web POST 自动 / 半自动附带 `csrf`
- [ ] WBI 签名（按日缓存 mixinKey）
- [ ] App 路径自动 AppSign + `access_key`
- [ ] gRPC 帧 + bin headers（见 [grpc.md](./grpc.md)）
- [ ] 统一 `code` 解析与错误类型（含 PGC `result`）
- [ ] 可选 gzip/brotli
- [ ] 可选系统代理

## 内容类型

| 场景 | Content-Type |
|------|----------------|
| 多数 POST 表单 | `application/x-www-form-urlencoded` |
| 部分 JSON POST（如激活 buvid） | `application/json` |
| 上传图片 | `multipart/form-data` |

## 与 Flutter 侧的边界

建议 **全部 B 站 HTTP/签名逻辑放在 Rust**，Flutter 只通过 FFI/消息通道调用高层 API：

```text
Flutter UI → core (Rust) → bilibili.com
```

这样 WBI/AppSign/Cookie 只维护一份实现。
