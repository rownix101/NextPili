# 评论端点

评论列表、发表与 gRPC 翻译。

Base：`https://api.bilibili.com` 
gRPC Base：`https://app.bilibili.com`（`Content-Type: application/grpc`）

---

## 评论列表

> UI **优先 gRPC** `MainList` / `DetailList`（含 `translation_switch`）。 
> REST 作回退；NextPili MVP 可只用 REST。

### 主楼（REST）

```
GET /x/v2/reply/main # 新分页（优先）
GET /x/v2/reply # 旧分页
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `oid` | ✓ | 对象 id：视频=aid，动态等见 type |
| `type` | ✓ | 1 视频；11 图文；12 专栏；17 动态… |
| `mode` | | 3 热度；2 时间 |
| `pagination_str` | | JSON：`{"offset":""}`，下一页用返回 offset |
| `plat` | | `1` |
| `seek_rpid` | | 定位某条评论 |
| `csrf` | | 可选 |

有 `nextOffset` 时走 `/main`，否则旧接口 `pn` 分页。

### 楼中楼

```
GET /x/v2/reply/reply
```

| 参数 | 说明 |
|------|------|
| `oid`, `type` | |
| `root` | 根评论 rpid |
| `pn`, `ps` | |
| `seek_rpid` | 可选定位 |

---

## 发表评论

```
POST /x/v2/reply/add
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `oid` | ✓ | |
| `type` | ✓ | |
| `message` | ✓ | 文本；可含表情/at |
| `root` | | 回复根评论 |
| `parent` | | 回复目标 |
| `plat` | | `1` |
| `csrf` | ✓ | |
| 其它 | | 富文本、投票、图片等扩展字段 |

---

## 删除 / 点赞 / 踩 / 置顶 / 举报

| 方法 | 路径 | 主要参数 |
|------|------|----------|
| POST | `/x/v2/reply/del` | `oid`, `type`, `rpid`, `csrf` |
| POST | `/x/v2/reply/action` | `oid`, `type`, `rpid`, `action` 0/1, `csrf` |
| POST | `/x/v2/reply/hate` | 同上 dislike |
| POST | `/x/v2/reply/top` | 置顶/取消置顶 |
| POST | `/x/v2/reply/report` | 举报 |
| GET | `/x/v2/reply/subject/interaction-status` | 评论区互动状态 |
| POST | `/x/v2/reply/subject/modify` | 修改评论区设置（UP） |

---

## 表情

```
GET /x/emote/user/panel/web?business=reply
```

`business`：`reply` | `dynamic` 等。

---

## 评论翻译（gRPC）

评论项提供「翻译 / 原文」切换；**不是 REST**，走 App gRPC。

### 服务

```text
POST https://app.bilibili.com/bilibili.main.community.reply.v1.Reply/TranslateReply
Content-Type: application/grpc
```

| 项 | 说明 |
|----|------|
| 请求消息 | `TranslateReplyReq` |
| 响应消息 | `TranslateReplyResp` |
| 服务路径 | `/bilibili.main.community.reply.v1.Reply/TranslateReply` |

### 请求字段（`TranslateReplyReq`）

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | int64 | 评论区类型（同 REST `type`，视频=1） |
| `oid` | int64 | 对象 id（视频=aid） |
| `rpids` | repeated int64 | 要翻译的评论 id 列表（通常传 1 个） |

### 响应字段（`TranslateReplyResp`）

| 字段 | 说明 |
|------|------|
| `translated_replies` | map：`rpid → Reply`（或子集） |
| 条目内 `translated_content` | 译文文本 |

### 列表侧开关（`ReplyControl` / gRPC 主列表）

评论控制结构里带翻译相关枚举：

| `TranslationSwitch` | 含义 |
|---------------------|------|
| `UNSPECIFIED` (0) | 未指定 |
| `UNSUPPORTED` (1) | 不支持翻译 |
| `SHOW_TRANSLATION` (2) | 可展示翻译按钮 |
| `SHOW_ORIGIN` (3) | 当前显示译文时可回原文 |

HTTP 列表模型也可能返回 `translation_switch` 字段。

UI 逻辑：

1. 仅当 `translationSwitch == SHOW_TRANSLATION` 时显示翻译按钮 
2. 已有 `translated_content` 则直接切换展示 
3. 否则调用 `TranslateReply`，写入 `translatedContent` 后切换 
4. 再点一次回到原文（本地切换，不重新请求）

### gRPC 帧格式（与其它 B 站 gRPC 相同）

```text
[压缩标志 1B][长度 4B big-endian][protobuf 载荷]
压缩标志：0 不压缩；1 gzip（payload > 64B 时 gzip）
成功：响应头 Grpc-Status: 0
```

请求需带 App gRPC headers（`access_key` / fawkes / locale 等），见 [auth/grpc.md](../auth/grpc.md)。

### NextPili 建议

| 阶段 | 做法 |
|------|------|
| MVP | REST 列表 + 发评 ✅（`reply_list` · `reply_add`） |
| 评论翻译 | 可先不做，或客户端侧接第三方翻译（隐私/准确度另议） |
| 完整实现 | 引入 gRPC 客户端 + reply proto，实现 `TranslateReply` |
| 列表 | 若走 gRPC `MainList`，可一并拿到 `translation_switch`；纯 REST 列表则看 `translation_switch` 字段是否仍返回 |
