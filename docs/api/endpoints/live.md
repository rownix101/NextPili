# 直播端点

直播列表、房间信息与弹幕 WebSocket。

Base：`https://api.live.bilibili.com`（除非另注）

---

## 推荐 / 分区 / 搜索

| 方法 | 路径 | 标记 | 说明 |
|------|------|------|------|
| GET | `/xlive/web-interface/v1/second/getUserRecommend` | | Web 推荐；`page`,`page_size` |
| GET | `/xlive/app-interface/v2/index/feed` | AppSign | App 首页 |
| GET | `/xlive/app-interface/v2/second/getList` | AppSign | 二级列表 |
| GET | `/xlive/app-interface/v2/index/getAreaList` | AppSign | 分区 |
| GET | `/room/v1/Area/getList` | AppSign | 分区（另一套） |
| GET | `/xlive/app-interface/v2/second/get_fav_tag` | AppSign | 喜爱分区 |
| POST | `/xlive/app-interface/v2/second/set_fav_tag` | AppSign | 设置 |
| GET | `/xlive/app-interface/v2/search_live` | AppSign | 搜索 |
| GET | `/xlive/web-ucenter/user/following` | Login | 关注的直播 |

---

## 房间

### 播放信息

```
GET /xlive/web-room/v2/index/getRoomPlayInfo
```

| 参数 | 说明 |
|------|------|
| `room_id` | ✓ |
| `protocol` | `0,1` |
| `format` | `0,1,2` |
| `codec` | `0,1` |
| `qn` | 80/150/400/10000/20000/30000… |
| `platform` | `web` |
| `ptype` | `8` |
| `dolby` | `5` |
| `panorama` | `1`（声明支持全景直播流；见 [video.md 全景视频](./video.md#全景视频360--panorama)） |
| WBI | ✓ |

### H5 信息

```
GET /xlive/web-room/v1/index/getH5InfoByRoom?room_id=
```

### 进房

```
POST /xlive/web-room/v1/index/roomEntryAction
```

`room_id`, `platform=pc`, `csrf`

### 用户维度房间信息（屏蔽词等）

```
GET /xlive/web-room/v1/index/getInfoByUser # WBI
```

---

## 弹幕

### 历史弹幕预取

```
GET /xlive/web-room/v1/dM/gethistory?roomid=
```

### WebSocket 令牌

```
GET /xlive/web-room/v1/index/getDanmuInfo # WBI; room_id / id
```

返回 host 列表 + `token`，用于连接弹幕 WS/WSS。

### 发送弹幕

```
POST /msg/send
```

WBI query + form：`roomid`,`msg`,`color`,`fontsize`,`mode`,`bubble`,`rnd`,`csrf`… 
表情弹幕另有字段。

### 表情包

```
GET /xlive/web-ucenter/v2/emoticon/GetEmoticons?platform=pc&room_id=
```

### 弹幕举报 / 点赞直播

```
POST /xlive/web-ucenter/v1/dMReport/Report
POST /xlive/app-ucenter/v1/like_info_v3/like/likeReportV3 # WBI body
```

---

## 屏蔽 / 禁言相关

```
POST /liveact/user_silent
POST /xlive/web-ucenter/v1/banned/AddShieldKeyword
POST /xlive/web-ucenter/v1/banned/DelShieldKeyword
POST /liveact/shield_user
```

---

## SuperChat

```
GET /av/v1/SuperChat/getMessageList?room_id=
POST /av/v1/SuperChat/report
```

---

## 贡献榜 / 粉丝勋章

```
GET /xlive/general-interface/v1/rank/queryContributionRank # WBI
GET /xlive/web-ucenter/user/MedalWall
GET /xlive/app-ucenter/v1/guard/MainGuardCardAll
```

---

## 清晰度 qn（直播）

| qn | 说明 |
|----|------|
| 80 | 流畅 |
| 150 | 高清 |
| 250 | 超清 |
| 400 | 蓝光 |
| 10000 | 原画 |
| 20000 | 4K |
| 30000 | 杜比 |

---

## 弹幕 WebSocket 协议

### 1. 取连接信息

```
GET /xlive/web-room/v1/index/getDanmuInfo # WBI; room_id
```

关键 `data`：

| 字段 | 说明 |
|------|------|
| `token` | 认证包 `key` |
| `host_list[]` | `{ host, wss_port, ws_port, … }` |

### 2. 建连

按 host 依次尝试：

```text
wss://{host}:{wss_port}/sub
```

全部失败则报错。

### 3. 包头（16 字节，big-endian）

| 偏移 | 类型 | 字段 | 说明 |
|------|------|------|------|
| 0 | u32 | `total_size` | 整包长度 = 16 + body |
| 4 | u16 | `header_size` | 固定 `0x10` |
| 6 | u16 | `protocol_ver` | 见下表 |
| 8 | u32 | `operation` | 操作码 |
| 12 | u32 | `seq` | 序列号 |

发送时 `PackageHeader.toBytes(contentSize)` 与此一致。

### 4. 操作码

| op | 方向 | 含义 |
|----|------|------|
| 2 | C→S | 心跳（body 可空） |
| 3 | S→C | 心跳回复（可忽略） |
| 5 | S→C | 业务消息（弹幕/礼物等，常压缩） |
| 7 | C→S | 认证 |
| 8 | S→C | 认证成功 → 开始心跳 |

### 5. 协议版本 `protocol_ver`（收包）

| ver | body |
|-----|------|
| 0 / 1 | 明文；可能是 JSON 或嵌套多包 |
| 2 | zlib 压缩（从 offset 0x10 起解压） |
| 3 | brotli 压缩（认证推荐 `protover: 3`） |

解压后仍是「包头 + body」串联，需按 `total_size` 循环切分。

### 6. 认证包（op=7）

Header：`protocolVer=1`，`operationCode=7`，`seq=1` 
Body：UTF-8 JSON：

```json
{
 "roomid": <真实房间号>,
 "uid": <用户 mid，未登录可 0>,
 "protover": 3,
 "platform": "web",
 "type": 2,
 "key": "<getDanmuInfo.token>"
}
```

收到 **op=8** 后启动心跳。

### 7. 心跳（op=2）

- 间隔 **30s**
- Header：`protocolVer=1`，`operationCode=2`，`seq` 递增
- Body 长度 0

### 8. 业务消息（op=5）

解压/切分后 body 多为 UTF-8 JSON，常见 `cmd`：

| cmd（示例） | 含义 |
|-------------|------|
| `DANMU_MSG` | 弹幕 |
| `SEND_GIFT` / `COMBO_SEND` | 礼物 |
| `SUPER_CHAT_MESSAGE` | SC |
| `INTERACT_WORD` | 进房/关注等 |
| `ONLINE_RANK_*` / 人气相关 | 在线/榜 |
| `ROOM_BLOCK_MSG` 等 | 房管/状态 |

完整 `cmd` 列表以实测与 [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) live 章为准。将 JSON 交给 UI 事件监听器。

### 9. 实现清单（Rust）

- [ ] `getDanmuInfo`（WBI）→ token + hosts 
- [ ] 多 host 故障转移 WSS 
- [ ] 16B 包头编解码 
- [ ] 认证 JSON + op7/8 
- [ ] 30s 心跳 op2 
- [ ] zlib / brotli 解压 + 粘包切分 
- [ ] 按 `cmd` 分发业务事件 

REST 历史弹幕预取：`GET .../dM/gethistory?roomid=`（进房前展示）。
