# 其它端点

音乐、电竞、Gaia 风控、SponsorBlock、下载与更新。

---

## 音乐 / BGM

```
GET /x/copyright-music-publicity/bgm/detail
POST /x/copyright-music-publicity/bgm/wish/update
GET /x/copyright-music-publicity/bgm/recommend_list
GET /audio/music-service/web/song/upper # 用户音频稿件
```

---

## 电竞

```
GET /x/esports/match/info
```

---

## 风控 / 人机验证（Gaia）

搜索、发评、发动态等可能返回 `v_voucher` / 触发极验。

### 流程

```text
业务接口返回 v_voucher
 → POST /x/gaia-vgate/v1/register (v_voucher, csrf?)
 → data 含 challenge / token 等（极验）
 → 前端完成 GeeTest
 → POST /x/gaia-vgate/v1/validate (challenge, seccode, token, validate)
 → 得到 gaia vtoken
 → 重试业务请求（Cookie: x-bili-gaia-vtoken=... 或 query gaia_vtoken）
```

### register

```
POST /x/gaia-vgate/v1/register
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 位置 | 说明 |
|------|------|------|
| `v_voucher` | body | 业务返回的凭证 |
| `csrf` | query | 已登录时带 `bili_jct` |

成功：`data` Map（challenge、gt、token 等，以实测为准）。

### validate

```
POST /x/gaia-vgate/v1/validate
```

| 参数 | 说明 |
|------|------|
| `challenge` | 极验 |
| `seccode` | |
| `token` | register 下发 |
| `validate` | 极验结果 |
| `csrf` | 已登录时 query |

### 相关

| 场景 | 说明 |
|------|------|
| 搜索 | `data.v_voucher` → validate → 重试 [search.md](./search.md) |
| buvid 激活 | `POST /x/internal/gaia-gateway/ExClimbWuzhi`（假 canvas 等 payload） |
| gRPC | Header `x-bili-gaia-vtoken` |

---

## SponsorBlock（第三方）

Base：`https://www.bsbsb.top`（可配置）

非 B 站官方。常用路径片段：

| 路径 | 用途 |
|------|------|
| `skipSegments` | 拉取跳过片段 |
| `voteOnSponsorTime` | 投票 |
| `viewedVideoSponsorTime` | 已观看上报 |
| `portVideo` | 移植 |
| `userInfo` | 用户 |
| `status/uptime` | 服务状态 |

完整 URL 与 JSON 字段以实现时对接服务为准。

---

## 下载 / 离线

下载能力以本地任务管理 + 复用 playurl 为主，无独立 B 站下载 API。

---

## 应用更新

使用项目自身的发布源（例如 GitHub Releases 或自建 CDN），不要依赖第三方客户端仓库。

---

## gRPC

完整传输、Headers、服务路径表见 **[auth/grpc.md](../auth/grpc.md)**。

摘要：

```text
POST https://app.bilibili.com{GrpcUrl.path}
Content-Type: application/grpc
帧：[compress:u8][len:u32be][protobuf] （>64B 常 gzip）
```

| 域 | 主路径前缀 |
|----|------------|
| 评论 | `/bilibili.main.community.reply.v1.Reply/*`（含 TranslateReply） |
| 弹幕 | `/bilibili.community.service.dm.v1.DM/DmSegMobile`、`DmView` |
| 动态 | `/bilibili.app.dynamic.v1.Dynamic/DynRed`、`Opus/*` |
| 私信 | `/bilibili.im.interface.v1.ImInterface/*`、`/bilibili.app.im.v1.im/*` |
| 稿件 | `/bilibili.app.viewunite.v1.View/View` |
| 音频 | `/bilibili.app.listener.v1.Listener/*` |
| 空间 | `/bilibili.app.interface.v1.Space/SearchArchive` |

MVP 可只用 REST；对齐评论翻译 / 弹幕分段 / 完整 IM 需要 gRPC 层。

---

## 端点索引

下列逻辑名便于跨文档检索（路径见各业务文档）：

**推荐/视频**：`recommendListApp/Web`, `feedDislike`, `hotList`, `ugcUrl`, `pgcUrl`, `pugvUrl`, `tvPlayUrl`, `playInfo`, `videoIntro`, `likeVideo`, `dislikeVideo`, `coinVideo`, `ugcTriple`, `pgcTriple`, `relatedList`, `heartBeat`, `historyReport`, `ab2c`, `onlineTotal`, `aiConclusion`, `videoTags`, `videoRelation`, `videoshot`, `getRankApi`, `popularSeries*`, `popularPrecious`

**收藏/稍后再看**：`favResourceList`, `favVideo`, `unfavAll`, `copy/move/clean/sortFav*`, `favFolder*`, `seeYouLater`, `toView*`, `mediaList`, `userSubFolder`, `favSeason*`

**关系**：`relation`, `relations`, `relationMod`, `followings`, `fans`, `blackLst`, `followUpTag`, `addUsers`, `followUpGroup`, `create/update/delFollowTag`, `followedUp`, `sameFollowing`, `sortFollowTag`

**评论/表情**：`replyList`, `replyReplyList`, `likeReply`, `hateReply`, `replyAdd`, `replyDel`, `replyTop`, `replyReport`, `replyInteraction`, `replySubjectModify`, `myEmote`

**用户/空间**：`userInfo`, `userStat*`, `memberInfo`, `space*`, `searchArchive`, `memberDynamic`, `dynSearch`, `getTopVideoApi`, `getRecentCoin/LikeVideoApi`, `getMemberViewApi`, `seasonArchives`, `seriesArchives`, `spaceSetting*`, `coinLog`, `loginLog`, `expLog`, `userRealName`, `upowerRank`, `memberGuard`, `liveMedalWall`

**历史**：`historyList`, `pauseHistory`, `historyStatus`, `clearHistory`, `delHistory`, `searchHistory`

**搜索**：`hotSearchList`, `searchDefault`, `searchSuggest`, `searchByType`, `searchAll`, `searchTrending`, `searchRecommend`, `topicPubSearch`

**动态**：`followUp`, `dynUplist`, `followDynamic`, `thumbDynamic`, `dynamicDetail`, `createDynamic`, `createTextDynamic`, `removeDynamic`, `uploadBfs`, `uploadImage`, `setTopDyn`, `rmTopDyn`, `dynamicReport`, `opusDetail`, `article*`, `dynReserve`, `dynTopicRcmd`, `dynPic`, `dynMention`, `editDyn`, `dynPrivatePubSetting`, `dynReaction`, `bubble`

**登录**：`getCaptcha`, `smsCode`, `logInByWebPwd`, `appSmsCode`, `logInByAppSms`, `loginByPwdApi`, `safeCenter*`, `oauth2AccessToken`, `getWebKey`, `getTVCode`, `qrcodePoll`, `qrcodeConfirm`, `logout`, `loginDevices`, `activateBuvidApi`

**消息**：`msgUnread`, `msgFeed*`, `msgSys*`, `session*`, `ackSessionMsg`, `sendMsg`, `removeMsg`, `setTop`, `setMsgDnd`, `imUserInfos`, `getSessionSs`, `getMsgDnd`, `setPushSs`, `imMsgReport`

**直播**：`liveList`, `liveRoomInfo*`, `sendLiveMsg`, `liveRoomDm*`, `liveFeedIndex`, `liveFollow`, `liveSecondList`, `liveAreaList`, `liveRoomAreaList`, `get/setLiveFavTag`, `liveSearch`, `getLiveInfoByUser`, `liveSetSilent`, `*ShieldKeyword`, `liveShieldUser`, `liveLikeReport`, `superChat*`, `liveDmReport`, `liveContributionRank`

**PGC**：`pgcInfo`, `pugvInfo`, `episodeInfo`, `pgcAdd/Del/Update`, `favPgc`, `pgcIndex*`, `pgcTimeline`, `pgcReview*`, `seasonStatus`, `pgcLikeCoinFav`, `pgcRank*`

**投票 / 预约 / 话题 / 课堂 / 音乐等**：见各业务文档。

---

## 实现建议

1. 在 Rust 实现 `WbiSign` + `AppSign` + Cookie jar，对 `nav` / `view` / `playurl` 联调  
2. 从抓包 JSON 或 protobuf 生成 Rust 结构体  
3. 按 MVP 顺序划分 `http` crate 端点模块  
4. 落地 [auth/grpc.md](../auth/grpc.md) 与 [live.md 弹幕 WS](./live.md#弹幕-websocket-协议)
