# 消息 / 私信端点

私信与系统通知。

Base 混用 `api.bilibili.com`、`api.vc.bilibili.com`、`message.bilibili.com`

> Web REST 覆盖未读/feed/系统通知与基础私信。 
> **完整 IM（会话置顶、关键词屏蔽、设置等）** 以 App gRPC 为准，见 [auth/grpc.md](../auth/grpc.md#私信-iminterface--appim)。

---

## 未读数

```
GET https://api.vc.bilibili.com/session_svr/v1/session_svr/single_unread
GET /x/msgfeed/unread
```

---

## 消息中心 Feed

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/x/msgfeed/reply` | 回复我的 |
| GET | `/x/msgfeed/at` | @我 |
| GET | `/x/msgfeed/like` | 收到的赞 |
| GET | `/x/msgfeed/like_detail` | 赞详情 |
| POST | `/x/msgfeed/del` | 删除某类通知 |
| POST | `/x/msgfeed/notice` | 通知设置 |

常用 query：`platform=web`,`build=0`,`mobi_app=web`, 分页 cursor。

---

## 系统通知

```
GET https://message.bilibili.com/x/sys-msg/query_notify_list?page_size=20&cursor=
POST https://message.bilibili.com/x/sys-msg/update_cursor # 已读
POST https://message.bilibili.com/x/sys-msg/del_notify_list
```

---

## 私信 Session

Base：`https://api.vc.bilibili.com`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/session_svr/v1/session_svr/get_sessions` | 会话列表；可 WBI |
| GET | `/account/v1/user/cards?uids=` | 会话用户卡片 |
| GET | `/svr_sync/v1/svr_sync/fetch_session_msgs` | 拉取消息 |
| GET/POST | `/session_svr/v1/session_svr/update_ack` | 已读 ack |
| POST | `/web_im/v1/web_im/send_msg` | 发送；WBI |
| POST | `/session_svr/v1/session_svr/remove_session` | 删除会话 |
| POST | `/session_svr/v1/session_svr/set_top` | 置顶 |
| POST | `/x/bplus/im/report/add` | 举报消息 |

### 拉取消息参数示例

| 参数 | 说明 |
|------|------|
| `talker_id` | 对方 mid |
| `session_type` | `1` 私聊 |
| `size` | 条数 |
| `sender_device_id` | `1` |
| `begin_seqno` / `end_seqno` | 可选范围 |
| WBI | 常见 |

### 发送

body/query 含 `msg[sender_uid]`、`msg[receiver_id]`、`msg[content]`（JSON 字符串）、`msg[msg_type]`、`csrf` 等。

---

## 免打扰 / 推送

```
POST /link_setting/v1/link_setting/set_msg_dnd
GET /link_setting/v1/link_setting/get_msg_dnd
GET /link_setting/v1/link_setting/get_session_ss
POST /link_setting/v1/link_setting/set_push_ss
GET /x/im/user_infos
```

（均在 `api.vc.bilibili.com`）

---

## gRPC IM

| 能力 | gRPC 方法（见 [auth/grpc.md](../auth/grpc.md)） |
|------|-----------------------------------------------|
| 发送 / 拉消息 | `SendMsg`, `SyncFetchSessionMsgs` |
| 会话列表 | `SessionMain`, `SessionSecondary`, `SessionDetail` |
| 未读 | `GetTotalUnread`, `ClearUnread` |
| 置顶 / 删除 | `PinSession`, `UnpinSession`, `DeleteSessionList` |
| 设置 / 关键词屏蔽 | `Get/SetImSettings`, `KeywordBlocking*` |

Web 与 gRPC 字段模型不同，Rust 侧应在 domain 层统一 `Session` / `Message`，勿把 JSON 与 protobuf 混进 UI。
