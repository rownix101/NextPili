# App gRPC（HTTP 封装）

App gRPC-over-HTTP 传输帧、Headers 与服务路径。

B 站 App 的 gRPC **不是独立端口**，而是：

```text
POST https://app.bilibili.com{GrpcUrl.path}
Content-Type: application/grpc
```

与 REST 共用 `app.bilibili.com` 域名；载荷为 **protobuf + 5 字节帧头**。

---

## 传输帧格式

请求体 / 响应体：

```text
[compress: u8][length: u32 BE][protobuf bytes]
```

| 字段 | 说明 |
|------|------|
| `compress` | `0` 不压缩；`1` gzip |
| `length` | 后续载荷字节数（big-endian） |
| body | protobuf 消息；若 compress=1 则为 gzip(proto) |

压缩规则：

- 序列化后 **> 64 字节** 才 gzip
- 响应解析看首字节，按需 `GZipDecoder`
- 成功：响应头 `Grpc-Status: 0`
- 失败：`Grpc-Status != 0`，细节常在 `Grpc-Status-Details-Bin`（base64，内嵌 `bilibili.rpc.Status`）

---

## 必需 Headers

### Content / 编码

```http
Content-Type: application/grpc
grpc-encoding: gzip
gzip-accept-encoding: gzip,identity
```

### 设备与元数据（多数为 base64 的 protobuf bin）

| Header | 内容 |
|--------|------|
| `user-agent` | 与 App REST 一致（如 BiliDroid HD） |
| `buvid` | 设备 buvid |
| `bili-http-engine` | `cronet` |
| `x-bili-trace-id` | trace |
| `x-bili-gaia-vtoken` | 可空；风控后填 |
| `x-bili-aurora-zone` | 可空或 `sh001` |
| `x-bili-device-bin` | `Device` proto → base64 |
| `x-bili-network-bin` | `Network` proto → base64 |
| `x-bili-locale-bin` | `Locale` proto → base64 |
| `x-bili-fawkes-req-bin` | `FawkesReq` proto → base64 |
| `x-bili-metadata-bin` | `Metadata` proto → base64（含 accessKey） |
| `x-bili-exps-bin` | 可空 |
| `authorization` | 登录时：`identify_v1 {access_key}` |

### HD 端常量（与 AppSign 对齐）

| 字段 | 值 |
|------|-----|
| `appId` | `5`（Device） |
| `build` | `2001100` |
| `versionName` | `2.0.1` |
| `mobiApp` | `android_hd` |
| `platform` / `device` | `android` |
| `channel` | `master` |
| `osver` | 如 `15` |
| locale | `zh` / `CN` / `Hans`，`Asia/Shanghai` |
| network | 如 `WIFI` |

`FawkesReq`：`appkey=android_hd`，`env=prod`，`sessionId` 随机 8 字符。 
`Metadata`：带 `accessKey`（可空）、`mobiApp`、`device`、`build`、`channel`、`buvid`、`platform`。

---

## 服务路径全表（`GrpcUrl`）

Base path 前缀一律挂在 `https://app.bilibili.com`。

### 评论 `bilibili.main.community.reply.v1.Reply`

| 方法 | 路径 | 用途 |
|------|------|------|
| MainList | `/bilibili.main.community.reply.v1.Reply/MainList` | 主列表（含 translation_switch） |
| DetailList | `.../DetailList` | 楼中楼 |
| DialogList | `.../DialogList` | 对话链 |
| SearchItem | `.../SearchItem` | 评论区搜索 |
| TranslateReply | `.../TranslateReply` | 评论翻译 |

REST 对照见 [endpoints/reply.md](../endpoints/reply.md)。 
`TranslateReply` 字段见 reply 文档专节。

### 弹幕 `bilibili.community.service.dm.v1.DM`

| 方法 | 路径 | 用途 |
|------|------|------|
| DmSegMobile | `/bilibili.community.service.dm.v1.DM/DmSegMobile` | 分段弹幕（主路径） |
| DmView | `/bilibili.community.service.dm.v1.DM/DmView` | 弹幕视图/配置 |

#### DmSegMobileReq（关键字段）

| 字段 | 说明 |
|------|------|
| `oid` | **cid** |
| `segment_index` | 分段索引，从 1 起；每段约 6 分钟 |
| `type` | `1` 视频 |

#### DmViewReq

| 字段 | 说明 |
|------|------|
| `pid` | aid |
| `oid` | cid |
| `type` | `1` |

详见 [endpoints/danmaku.md](../endpoints/danmaku.md)。

### 动态

| 方法 | 路径 | 用途 |
|------|------|------|
| DynRed | `/bilibili.app.dynamic.v1.Dynamic/DynRed` | 动态红点未读 |
| OpusSpaceFlow | `/bilibili.app.dynamic.v2.Opus/OpusSpaceFlow` | 空间图文流 |
| OpusDetail | `/bilibili.app.dynamic.v2.Opus/OpusDetail` | 图文详情 |

### 私信 `ImInterface` + `app.im`

| 方法 | 路径 | 用途 |
|------|------|------|
| SendMsg | `/bilibili.im.interface.v1.ImInterface/SendMsg` | 发送 |
| ShareList | `.../ShareList` | 分享列表 |
| SyncFetchSessionMsgs | `.../SyncFetchSessionMsgs` | 拉消息 |
| GetTotalUnread | `.../GetTotalUnread` | 未读总数 |
| SessionDetail | `.../SessionDetail` | 会话详情 |
| SessionMain | `/bilibili.app.im.v1.im/SessionMain` | 主会话列表 |
| SessionSecondary | `.../SessionSecondary` | 次级会话 |
| ClearUnread | `.../ClearUnread` | 清未读 |
| SessionUpdate | `.../SessionUpdate` | 更新会话 |
| PinSession / UnpinSession | `.../PinSession` / `UnpinSession` | 置顶 |
| DeleteSessionList | `.../DeleteSessionList` | 删会话列表 |
| GetImSettings / SetImSettings | 设置读写 | |
| KeywordBlockingList/Add/Delete | 关键词屏蔽 | |

Web REST 私信见 [endpoints/msg.md](../endpoints/msg.md)；完整 IM UX 以 gRPC 为准。

### 稿件聚合 ViewUnite

| 方法 | 路径 | 用途 |
|------|------|------|
| View | `/bilibili.app.viewunite.v1.View/View` | 统一稿件详情 |

### 音频 Listener

| 方法 | 路径 | 用途 |
|------|------|------|
| PlayURL | `/bilibili.app.listener.v1.Listener/PlayURL` | 音频播放地址 |
| Playlist | `.../Playlist` | 播放列表 |
| ThumbUp | `.../ThumbUp` | 点赞 |
| TripleLike | `.../TripleLike` | 三连 |
| CoinAdd | `.../CoinAdd` | 投币 |

### 空间

| 方法 | 路径 | 用途 |
|------|------|------|
| SearchArchive | `/bilibili.app.interface.v1.Space/SearchArchive` | 空间投稿搜索（gRPC） |

REST 对照：`/x/space/wbi/arc/search`。

---

## 调用流程（Rust 建议）

```text
1. 组装 Request message → write_to_bytes
2. 可选 gzip（>64B）→ 拼 5 字节帧头
3. POST app.bilibili.com + path，带 GrpcHeaders
4. 检查 Grpc-Status == 0
5. 解帧 → 可选 gunzip → parse Response message
6. Grpc-Status 非 0 → 解析 Status-Details-Bin 为业务错误
```

能力清单：

- [ ] protobuf 生成（从上游 `.proto` 或社区 protobuf 定义）
- [ ] 帧编解码 + gzip
- [ ] bin headers（Device / Metadata / Fawkes / Locale / Network）
- [ ] `access_key` → `authorization` + metadata
- [ ] 与 Cookie 账号体系对齐（同一账号槽）

---

## 与 REST 的选型

| 场景 | 建议 |
|------|------|
| MVP 播放 / 登录 / 推荐 | **仅 REST** |
| 评论列表 + 翻译（gRPC） | gRPC `MainList` + `TranslateReply` |
| 分段弹幕（完整） | gRPC `DmSegMobile`（或 REST `seg.so` 过渡） |
| 私信完整功能 | gRPC IM 优先 |
| 音频播客 | gRPC Listener |

