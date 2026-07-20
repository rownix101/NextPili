# 弹幕端点

弹幕拉取、发送、屏蔽与 gRPC 分段。

传输与 Headers：[auth/grpc.md](../auth/grpc.md)

Base REST：`https://api.bilibili.com` 
gRPC Base：`https://app.bilibili.com`

---

## 拉取弹幕

**主路径推荐 gRPC 分段弹幕**；REST `seg.so` 作兼容/过渡。

### gRPC 分段（推荐）

```text
POST /bilibili.community.service.dm.v1.DM/DmSegMobile
```

| 请求字段 | 说明 |
|----------|------|
| `oid` | **cid** |
| `segment_index` | 从 **1** 起；约每 **6 分钟** 一段 |
| `type` | `1` 视频 |

响应：`DmSegMobileReply`（elems 列表：进度、模式、颜色、文本、midHash、id 等）。  
大包建议在后台线程 / isolate 解析。

### gRPC 视图配置

```text
POST /bilibili.community.service.dm.v1.DM/DmView
```

| 字段 | 说明 |
|------|------|
| `pid` | aid |
| `oid` | cid |
| `type` | `1` |

含弹幕开关、蒙版、字幕相关元数据等（以 proto 为准）。

### REST 分段（过渡）

```
GET /x/v2/dm/web/seg.so
```

| 参数 | 说明 |
|------|------|
| `type` | `1` |
| `oid` | cid |
| `pid` | aid |
| `segment_index` | 同 gRPC |

响应为 **protobuf** 字节流（非 JSON envelope）。 
Web 播放页信息 `/x/player/wbi/v2` 也会带弹幕相关配置。

> MVP 可用 `seg.so` 或社区 XML；完整体验用 `DmSegMobile`。

---

## 发送弹幕

```
POST /x/v2/dm/post
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `type` | ✓ | `1` 视频；`2` 漫画 |
| `oid` | ✓ | **cid** |
| `msg` | ✓ | 文本，&lt;100 字 |
| `bvid` | ✓ | （与 aid 二选一体系，推荐 bvid） |
| `mode` | | `1` 滚动 `4` 底 `5` 顶；`7` 高级等受权限限制 |
| `progress` | | 出现时间 **毫秒** |
| `color` | | 默认 `16777215` 白；彩色会员时仍可先发白底 |
| `fontsize` | | 默认 25 |
| `pool` | | `0` 普通 `1` 字幕 `2` 特殊 |
| `rnd` | | **微秒时间戳**；有则冷却约 5s，无则约 90s（建议始终携带） |
| `colorful` | | `60001` 会员渐变彩色 |
| `checkbox_type` | | `4` 带 UP 标识 |
| `csrf` | ✓ | Cookie 登录 |

成功：`data` → `DanmakuPost`（含 dmid 等）。

---

## 弹幕互动

### 点赞

```
POST /x/v2/dm/thumbup/add
```

| 参数 | 说明 |
|------|------|
| `op` | `1` 赞 / `2` 取消 |
| `dmid` | 弹幕 id |
| `oid` | cid |
| `platform` | `web_player` |
| `polaris_app_id` | `100` |
| `polaris_platform` | `5` |
| `spmid` / `from_spmid` | 如 `333.788.0.0` |
| `statistics` | JSON 字符串，appId/platform 等 |
| `csrf` | ✓ |

### 举报

```
POST /x/dm/report/add
```

| 参数 | 说明 |
|------|------|
| `cid` / `originCid` | cid |
| `dmid` | |
| `reason` | 原因码 |
| `block` | 是否拉黑 |
| `content` | 可选补充 |
| polaris / spmid / statistics | 同点赞 |
| `csrf` | ✓ |

`data.block` 业务码示例：`0` 已提交；`-1` 未激活；`-4` 过频；`-5` 已举报过 等。

### 撤回自己的弹幕

```
POST /x/dm/recall
```

| 参数 | 说明 |
|------|------|
| `dmid` | |
| `cid` | |
| `type` | `1` |
| `csrf` | ✓ |

### 编辑状态（UP）

```
POST /x/v2/dm/edit/state
```

| 参数 | 说明 |
|------|------|
| `dmids` | 逗号分隔 id |
| `oid` | cid |
| `state` | `0` 取消删除 `1` 删除 `2` 保护 `3` 取消保护 |
| `type` | `1` |
| `csrf` | ✓ |

> 注：`edit/state` 路径以实现前实测为准。

---

## 屏蔽词

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/x/dm/filter/user` | 列表 → `DanmakuBlockDataModel` |
| POST | `/x/dm/filter/user/add` | `type`：`0` 关键词 `1` 正则 `2` 用户；`filter`；`csrf` |
| POST | `/x/dm/filter/user/del` | `ids`；`csrf` |

---

## 与播放的关系

| 能力 | 接口 |
|------|------|
| 分段拉取 | gRPC `DmSegMobile` / REST `seg.so` |
| 发送 / 赞 / 举报 | REST POST + csrf |
| 直播弹幕 | 见 [live.md](./live.md#弹幕-websocket-协议)（另一套 WS） |
| 字幕 | 播放页 `/x/player/wbi/v2` → subtitle 列表，非弹幕池 |

---

## NextPili 建议

| 阶段 | 做法 |
|------|------|
| MVP | REST 发弹幕 + `seg.so` 或社区 XML 拉取 ✅（`danmaku_post` · `danmaku_segments`） |
| 完整实现 | gRPC `DmSegMobile` + `DmView` + 屏蔽词同步 |
| 直播 | 独立 WS 协议，勿与视频弹幕混用（发送 REST 见 [live.md](./live.md)） |
