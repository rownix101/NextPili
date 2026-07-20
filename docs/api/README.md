# Bilibili API

描述 NextPili 使用的 HTTP、gRPC 与直播 WebSocket 约定。

本文档是**面向客户端实现**的规范：参数、鉴权与响应形状，而非官方完整公开目录。

**相关：** [Documentation](../README.md) · [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) · [架构](../architecture.md) · [Style Pathway](../writing.md)

---

## 概述

NextPili 通过三种传输与 B 站通信：

| 传输 | 用途 |
|------|------|
| REST (JSON) | 登录、推荐、详情、playurl、收藏等 MVP 主体 |
| gRPC-over-HTTP | 评论列表/翻译、分段弹幕、IM、ViewUnite、音频 |
| 直播 WebSocket | 房间实时弹幕、礼物、醒目留言 |

相对路径默认拼到 `https://api.bilibili.com`。域名、Cookie 与多账号路由见 [鉴权概述](./auth/overview.md)。

---

## 主题

### 鉴权

| 文档 | 说明 |
|------|------|
| [auth/overview.md](./auth/overview.md) | 域名、通用响应、Cookie、Headers、账号槽位 |
| [auth/wbi.md](./auth/wbi.md) | Web WBI 签名（`w_rid` / `wts`） |
| [auth/app-sign.md](./auth/app-sign.md) | App `appkey` + `sign` |
| [auth/grpc.md](./auth/grpc.md) | App gRPC 帧格式、Headers、服务路径 |

### 端点

| 文档 | 说明 |
|------|------|
| [endpoints/login.md](./endpoints/login.md) | 登录、登出、设备 |
| [endpoints/video.md](./endpoints/video.md) | 推荐、详情、playurl、互动、互动视频、全景、多语言音轨、字幕 |
| [endpoints/reply.md](./endpoints/reply.md) | 评论（REST + gRPC 翻译） |
| [endpoints/danmaku.md](./endpoints/danmaku.md) | 弹幕（REST + gRPC 分段） |
| [endpoints/search.md](./endpoints/search.md) | 搜索（含 Gaia 风控） |
| [endpoints/user.md](./endpoints/user.md) | 当前用户、历史、稍后再看、关系 |
| [endpoints/member.md](./endpoints/member.md) | 空间、投稿、关注分组 |
| [endpoints/fav.md](./endpoints/fav.md) | 收藏夹、订阅、笔记 |
| [endpoints/dynamics.md](./endpoints/dynamics.md) | 动态、图文、话题、投票 |
| [endpoints/live.md](./endpoints/live.md) | 直播 REST + 弹幕 WebSocket |
| [endpoints/pgc.md](./endpoints/pgc.md) | 番剧、影视、课堂 |
| [endpoints/msg.md](./endpoints/msg.md) | 私信与通知 |
| [endpoints/misc.md](./endpoints/misc.md) | Gaia、SponsorBlock、路径索引 |

---

## 约定

### Base URL

```text
https://api.bilibili.com
```

其它域名见 [auth/overview.md](./auth/overview.md#域名)。

### 通用响应

```json
{
  "code": 0,
  "message": "0",
  "ttl": 1,
  "data": {}
}
```

| 条件 | 行为 |
|------|------|
| `code == 0` | 成功；载荷在 `data`（部分 PGC 在 `result`） |
| `code != 0` | 业务错误；向用户展示 `message` |
| 搜索建议等 | 成功体可能在 `result`，且可能是 JSON **字符串** |

### 鉴权摘要

| 方式 | 场景 |
|------|------|
| Cookie（`SESSDATA`、`bili_jct`、`DedeUserID`、`buvid3` …） | 绝大多数 Web 接口 |
| CSRF（`csrf` / `biliCSRF` = cookie `bili_jct`） | 绝大多数 Web POST |
| WBI（`w_rid` + `wts`） | `/wbi/` 路径或需显式 WBI 的 GET |
| AppSign（`appkey` + `ts` + `sign`） | `app.bilibili.com` 及部分 passport 接口 |
| `access_key` | App REST / gRPC 登录态 |
| gRPC headers | `authorization: identify_v1 …` 与二进制 protobuf headers |

### 建议实现顺序

1. 鉴权基础设施 — Cookie jar、CSRF、WBI、AppSign、buvid、账号路由  
2. 登录 — 短信（全端）/ TV 扫码（桌面·平板）  
3. 首页推荐、热门、视频详情、playurl  
4. 评论（REST）与弹幕（`seg.so` 或 gRPC）  
5. 搜索（预留 Gaia）  
6. 空间、历史、稍后再看、收藏  
7. 动态、直播（REST + WS）、番剧  
8. 消息与其余 gRPC 面  

---

## 文档维护

- 需要 `WBI` / `AppSign` / `Login` / `CSRF` 的接口在参数表中标注。
- 「必要」列反映客户端调用约定；服务端可能另有可选字段。
- 响应表只列 UI 与领域逻辑所需字段，不枚举全部 wire 字段。
- 服务端行为变化时，以实测为准并回写本文档。
