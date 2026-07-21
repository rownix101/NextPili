# 视频相关端点

推荐、详情、播放地址、互动、互动视频、全景、多语言音轨与字幕。

默认 Base：`https://api.bilibili.com`

标记：`WBI` / `AppSign` / `Login` / `CSRF`

---

## 推荐 / 热门 / 排行

### Web 推荐

```
GET /x/web-interface/wbi/index/top/feed/rcmd
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `version` | | `1` |
| `feed_version` | | `V8` |
| `homepage_ver` | | `1` |
| `ps` | ✓ | 每页数量 |
| `fresh_idx` | ✓ | 刷新序号，从 0/1 递增 |
| `brush` | | 同 `fresh_idx` |
| `fresh_type` | | `4` |
| WBI | ✓ | |

过滤：只保留 `goto == "av"`，并应用黑名单与推荐过滤规则。

### App 推荐

```
GET https://app.bilibili.com/x/v2/feed/index
```

| 参数 | 说明 |
|------|------|
| `idx` | 刷新序号；0 时 `pull=true` |
| `build` | `2001100` |
| `mobi_app` | `android_hd` |
| `device` | `pad` |
| `column` | `4` |
| `fnval` | `976` |
| `qn` | `32` |
| `force_host` | `2`（https） |
| `fourk` | `1` |
| `statistics` | JSON 字符串 |
| AppSign | 拦截器自动 |

自定义 headers 含 `buvid`、`User-Agent`（BiliDroid HD）等。

### 热门

```
GET /x/web-interface/popular
```

| 参数 | 说明 |
|------|------|
| `pn` | 页码 |
| `ps` | 每页数量 |

### 不感兴趣（App）

```
GET https://app.bilibili.com/x/feed/dislike
GET https://app.bilibili.com/x/feed/dislike/cancel
```

参数含稿件 id 与不感兴趣原因等。

### 排行榜

#### 分区排行（UGC · 首页「分区」）

```
GET /x/web-interface/ranking/v2
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `rid` | | 主分区 tid；`0` = 全站。仅主分区 |
| `type` | | `all`（默认）· `rookie` · `origin` |
| `web_location` | | 常用 `333.934` |
| WBI | ✓ | `w_rid` / `wts` |

返回约前 100 条，无分页。`data.list[]` 字段形状同稿件详情精简（`aid`/`bvid`/`title`/`pic`/`duration`/`owner`）。

```json
{
  "code": 0,
  "data": {
    "note": "根据稿件内容质量、近期的数据综合展示，动态更新",
    "list": [
      {
        "aid": 170001,
        "bvid": "BV1xx411c7mD",
        "title": "示例",
        "pic": "http://i0.hdslb.com/bfs/archive/x.jpg",
        "duration": 120,
        "owner": { "mid": 1, "name": "UP" }
      }
    ]
  }
}
```

NextPili：`feed_regions`（静态主分区表）+ `feed_ranking(rid, rank_type)`。

#### 其它排行入口

```
GET /pgc/web/rank/list # 番剧排行 WBI
GET /pgc/season/rank/web/list # 剧场排行 WBI
GET /x/web-interface/popular/series/list
GET /x/web-interface/popular/series/one # number=
GET /x/web-interface/popular/precious # WBI
```

---

## 视频详情

### 基本信息

```
GET /x/web-interface/view
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `bvid` 或 `aid` | ✓ | 稿件 id |

`data` 关键：`bvid/aid/cid/title/desc/owner/stat/pages/rights/dimension/...`

#### `rights` 关键字段

| 字段 | 说明 |
|------|------|
| `is_stein_gate` | `1` = **互动视频**（分支剧情 / Stein Gate） |
| `is_cooperation` | `1` = 联合投稿（列表角标「合作」） |

其它常见 `rights` 位（官方/proto 有，可按需反序列化）：`bp`/`elec`/`download`/`movie`/`pay`/`hd5`/`no_reprint`/`autoplay`/`ugc_pay`/`ugc_pay_preview`/`no_background`/`arc_pay`/`pay_free_watch` 等。实现时可按需扩展。

> 列表场景的互动标记字段名不同：用户空间/投稿列表等用 **`is_steins: bool`**（不是 `is_stein_gate`）；列表封面角标可显示「互动」。

### 关系状态（是否赞/币/收藏/关注）

```
GET /x/web-interface/archive/relation
```

| 参数 | 说明 |
|------|------|
| `aid`, `bvid` | |

`Login` 后数据才有意义。

#### Example · 成功

```json
{
  "code": 0,
  "message": "0",
  "data": {
    "attention": 1,
    "favorite": 1,
    "season_fav": 0,
    "like": 1,
    "dislike": 0,
    "coin": 2
  }
}
```

| 字段 | 含义 |
|------|------|
| `like` / `favorite` / `attention` | 非 0 为真 |
| `coin` | 已投币数 0–2 |

### 相关推荐

```
GET /x/web-interface/archive/related
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `aid` 或 `bvid` | ✓ | 与详情一致，二选一 |

`data` 为**数组**（不是 `{list:…}` 信封）。每项字段与热门列表 archive 同形；客户端映射到 feed 卡片：

| 字段 | 用途 |
|------|------|
| `aid` / `bvid` | 跳转 id |
| `title` | 标题 |
| `pic` | 封面（`//` → `https:`） |
| `duration` | 秒 → 毫秒 |
| `owner.name` | UP 名 |

**成功 example**

```json
{
  "code": 0,
  "message": "0",
  "ttl": 1,
  "data": [
    {
      "aid": 170001,
      "bvid": "BV1xx411c7mD",
      "title": "示例相关稿件",
      "pic": "//i0.hdslb.com/bfs/archive/a.jpg",
      "duration": 90,
      "owner": { "mid": 1, "name": "UP", "face": "" },
      "stat": { "view": 1000, "danmaku": 10, "reply": 1, "favorite": 2, "coin": 3, "share": 0, "like": 20 }
    }
  ]
}
```

FRB：`video_related(id)` → `Vec<FeedItemDto>`。

### 分 P 列表（avid/bvid → cid）

```
GET /x/player/pagelist
```

| 参数 | 说明 |
|------|------|
| `aid` 或 `bvid` | |

### 标签

```
GET /x/web-interface/view/detail/tag
```

### 在线人数

```
GET /x/player/online/total?aid=&bvid=&cid=
```

### AI 总结

```
GET /x/web-interface/view/conclusion/get
```

| 参数 | 说明 |
|------|------|
| `bvid`, `cid`, `up_mid` | |
| WBI | ✓ |

### 视频预览缩略图（进度条）

```
GET /x/player/videoshot?aid=&cid=&index=1
```

---

## 播放地址

### UGC

```
GET /x/player/wbi/playurl
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `avid` / `bvid` | ✓ | |
| `cid` | ✓ | |
| `qn` | | 清晰度，默认 80 |
| `fnval` | ✓ | `4048` 拿 dash 全格式 |
| `fnver` | | `0` |
| `fourk` | | `1` |
| `try_look` | | `1` 未登录尝试 1080p |
| `voice_balance` | | 响度均衡 |
| `gaia_source` | | `pre-load` |
| `isGaiaAvoided` | | `true` |
| `web_location` | | `1315873` |
| `dm_img_list` | | `'[]'` |
| `dm_img_str` | | 随机 base64 串 |
| `dm_cover_img_str` | | 随机 base64 串 |
| `dm_img_inter` | | 固定 JSON |
| `cur_language` | | **音轨/配音语言**；切换多语言或 AI 原声时传入（见下） |
| WBI | ✓ | |

`fnval` 位标志：DASH、HDR、4K、杜比、AV1 等（见 bilibili-API-collect）。

### 多语言音频 / AI 原声翻译

部分稿件（含 AI 配音、多语种音轨）在 **playurl 响应** 中返回语言列表，而不是独立 REST 资源接口。

#### 响应字段（`PlayUrlModel`）

| 字段 | 说明 |
|------|------|
| `cur_language` | 当前音轨语言代码（如 `zh` / `en` / 服务端自定义） |
| `language.support` | 是否支持切换语言 |
| `language.items[]` | 可选语言列表 |

`language.items[]` 元素（`LanguageItem`）：

| 字段 | 说明 |
|------|------|
| `lang` | 语言代码，回传给 `cur_language` |
| `title` | 展示名 |
| `subtitle_lang` | 关联字幕语言（若有） |
| `production_type` | `2` = **AI 生成**（客户端可在 title 后追加「（AI）」） |

排序建议：含 `zh` 的优先，非 AI 优先于 AI。

#### 切换流程

```text
1. 首次 playurl → 解析 language.items / cur_language
2. 播放器展示「翻译 / 多语言」菜单
3. 用户选择 lang
4. 再次请求 playurl，query 带 cur_language=<lang>
5. 用新 dash.audio 替换音轨（切换通常需登录）
6. lang 传空字符串 = 关闭翻译 / 回到默认
```

> 注意：这是 **服务端已有的多语/AI 音轨流**，不是客户端本地语音识别。无 `language.items` 时不显示菜单。

#### 与字幕的区别

| | 多语言/AI **音轨** | **字幕** |
|--|-------------------|----------|
| 数据来源 | playurl 的 `language` + 对应 `dash.audio` | `/x/player/wbi/v2` 的 `subtitle` |
| 切换方式 | 改 `cur_language` 重拉 playurl | 下载 `subtitle_url` JSON → 转 VTT/SRT |
| AI 标记 | `production_type == 2` | 字幕 `type == 1` →「（AI）」 |
| 登录 | 切换语言通常要求登录 | 一般可拉 |

### PGC（番剧）

```
GET /pgc/player/web/v2/playurl
```

参数类似，用 `ep_id` / `season_id` + `cid`；成功体在 `result.video_info`。

### 课堂 PUGV

```
GET /pugv/player/web/playurl
```

### TV

```
GET /x/tv/playurl
```

| 参数 | 说明 |
|------|------|
| `access_key` | 登录 |
| `avid`/`cid`/`qn`/`fnval`… | |
| AppSign | ✓ |

### 播放页附加信息（字幕 / 互动图 / 看点）

```
GET /x/player/wbi/v2
```

| 参数 | 说明 |
|------|------|
| `aid`/`bvid`, `cid` | |
| `season_id` / `ep_id` | PGC 可选 |
| WBI | ✓ |

`data` 关键字段：

| 字段 | 说明 |
|------|------|
| `last_play_cid` | 上次播放到的分 P `cid`（可做「续播」） |
| `subtitle` | 字幕轨列表 |
| `view_points` | 视频看点 / 章节分段 |
| `interaction` | **互动视频图信息**（非互动视频为 `null`） |

#### 字幕

响应 `data.subtitle` 含字幕轨列表：

| 字段 | 说明 |
|------|------|
| `lan` | 语言代码 |
| `lan_doc` | 展示名 |
| `subtitle_url` | 字幕 JSON 地址（常为 `//aisubtitle…` / `//i0…`，请求时加 `https:`） |
| `subtitle_url_v2` | 官方播放器内部用的不透明路径（`subtitle.bilibili.com` + 加密段）；**第三方客户端勿用**，会 TLS/网络失败 |
| `type` | `1` = AI 字幕（可标「（AI）」） |

字幕 JSON 体为 `body: [{from, to, content, ...}]`，客户端转 VTT/SRT：

```
GET https:{subtitle_url}  (Referer: https://www.bilibili.com) → json → VTT/SRT
```

实现约定：解析列表时**优先 `subtitle_url`**；仅当其为空且 `subtitle_url_v2` 形如可 GET 的 CDN 链接时才回退。

与 **AI 原声音轨** 相互独立：可只开字幕、只换音轨、或同时使用。

#### `interaction`（互动视频）

| 字段 | 说明 |
|------|------|
| `graph_version` | 互动图版本号；请求分支边信息时必带 |
| `history_node` | 上次走到的节点（若有） |
| `history_node.node_id` | 节点 id |
| `history_node.title` | 节点标题 |
| `history_node.cid` | 节点对应分 P `cid` |

#### `view_points`（看点 / 章节）

元素（`ViewPoint`）：

| 字段 | 说明 |
|------|------|
| `type` | 仅在 `type == 2` 时启用进度条分段 |
| `from` / `to` | 起止秒 |
| `content` | 看点标题 |
| `imgUrl` | 预览图 |

---

## 互动视频（Stein Gate）

B 站「互动视频」是带分支剧情的 UGC 稿件：每个选择对应一条边（edge）与目标节点分片（`cid`）。 
互动视频应支持完整播放链路。

### 识别

| 来源 | 字段 | 说明 |
|------|------|------|
| 视频详情 `/x/web-interface/view` | `data.rights.is_stein_gate == 1` | 详情页标题前缀「互动视频」 |
| 空间/投稿列表等 | `is_steins == true` | 封面角标「互动」 |
| 播放页 `/x/player/wbi/v2` | `data.interaction != null` | 含 `graph_version`，用于拉边 |

### 边信息（选项列表）

```
GET /x/stein/edgeinfo_v2
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `bvid` | ✓ | 稿件 bvid |
| `graph_version` | ✓ | 来自 `playInfo.interaction.graph_version` |
| `edge_id` | | 当前边 id；**首次进入不传**，选完选项后把选项 `id` 作为下一次 `edge_id` |

Base：`https://api.bilibili.com`（相对路径）。该接口通常直接 GET，不走 WBI。

#### 响应

```text
data
└── edges
 └── questions[] # 通常取 first
 └── choices[]
 ├── id # 边 id → 下次 edge_id
 ├── cid # 目标分片 cid → 切流
 └── option # 按钮文案
```

最小实现可只消费 `edges.questions[].choices[]`（`id` / `cid` / `option`）；其余字段（如 `story_list`、`hidden_vars`）按需扩展。选项可复用分 P 切换逻辑。

### 客户端流程

```text
1. view → rights.is_stein_gate == 1
2. playInfo (player/wbi/v2) → interaction.graph_version
3. GET /x/stein/edgeinfo_v2?bvid=&graph_version=   # 首次无 edge_id
4. 正常 playurl 播当前 cid
5. 播放完成：
   - 若 choices 非空 → 展示选项，不进入自动下一集
   - 用户点选项：换 cid 重拉 playurl，并以 choice.id 作为 edge_id 再拉边
6. 互动会话内保留 graph_version；离开互动稿件时清空
```

### 与普通分 P / 合集的差异

| | 普通多 P / ugc_season | 互动视频 |
|--|----------------------|----------|
| 分片枚举 | `pages[]` / season episodes | 图上节点，按选择动态展开 |
| 切换参数 | 用户点分 P | `edge_id` + 目标 `cid` |
| 播完行为 | 下一 P / 循环 / 相关推荐 | **先出选项**，无选项才走默认收尾 |
| 状态保留 | 无 | `graph_version` 整片共享 |

### NextPili 落地建议

1. 详情模型保留 `rights.is_stein_gate`；列表保留 `is_steins` 角标。
2. `playInfo` 解析 `interaction.graph_version`（及可选 `history_node` 用于续看节点）。
3. 播放器在 `is_stein_gate` 时订阅「播放结束 → 展示 choices」；选项点击走「换 cid + 再拉 edgeinfo」。
4. 非关键路径：笔记 H5 的 `is_stein_gate` 查询参数。

---

## 全景视频（360° / Panorama）

B 站支持 **全景（360°）视频** 与 **全景直播**。播放侧需要把 equirectangular 等投影画面映射为可拖拽/陀螺仪视角，而不是普通平面缩放。

### 识别线索

UGC 全景播放器可分阶段实现；协议层已有多处信号，应预留：

| 来源 | 字段 / 约定 | 说明 |
|------|-------------|------|
| 视频详情 `rights` | 社区/官方常见 **`is_360`**（`1` = 全景） | 建议解析并用于角标/播放器 |
| App playurl gRPC | `PlayAbilityConf` / `PlayArcConf` 的 **`panorama_conf`** | `ConfType.PANORAMA = 27`；`ArcConf.is_support` / `disabled` 表示能力开关 |
| playershared | `SettingItemType.SETTING_PANORAMA` | 播放器设置项枚举 |
| 直播 playInfo | 请求参数 **`panorama=1`** | 用于获取全景直播流能力 |

Web `playurl` JSON 通常与普通稿共用 dash 流；是否全景由 **稿件属性** 决定，流本身多为 equirectangular 2:1 画幅。实现时勿仅凭分辨率判断。

### 直播侧

```
GET /xlive/web-room/v2/index/getRoomPlayInfo
```

| 参数 | 说明 |
|------|------|
| `panorama` | `1`（固定携带） |
| 其它 | 见 [live.md](./live.md) |

全景直播房间在响应的协议/格式列表中可能多出对应条目；播放器需按房间能力切换 360 渲染。

### 与互动视频、杜比全景声的区别

| 概念 | 含义 | 识别 |
|------|------|------|
| **互动视频** | 分支剧情选项 | `rights.is_stein_gate` / `is_steins` |
| **全景视频** | 360° 空间画面可环视 | `rights.is_360`（建议）/ gRPC `panorama_conf` |
| **杜比全景声** | 空间 **音频**（Atmos） | playurl 音质 id `30250`/`30255`，与画面全景无关 |

### NextPili 落地建议

1. **模型**：`rights` 增加 `is_360`；列表若有类似布尔字段一并映射。
2. **播放器**：`is_360 == 1` 时走 360 渲染路径（投影 + 拖拽/键鼠环视；移动端可接陀螺仪）。mpv 系可考虑 `video-rotate` / 全景脚本或自研 shader；Flutter 纹理层也可做。
3. **直播**：保持 `panorama=1`；房间若声明全景能力则复用同一套渲染。
4. **优先级**：低于普通播放与互动视频；可先做识别 + 降级提示（「全景稿，暂以平面播放」），再补完整环视。
5. **gRPC 路线**（可选）：若后续接 App `playurl`/`playview`，读取 `panorama_conf.is_support` 作为能力门闩。

---

## 互动操作（点赞 / 投币 / 收藏等）

桌面客户端默认走 **Web Cookie + csrf**（下列 Web 端点）；App 端点保留作对照。

### 点赞（Web · 实现用）

```
POST /x/web-interface/archive/like
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 说明 |
|------|------|
| `aid` | ✓ |
| `like` | `1` 点赞 / `2` 取消 |
| `csrf` | ✓ `bili_jct` |

#### Example · form

```text
aid=170001&like=1&csrf=<bili_jct>
```

### 点赞（App）

```
POST https://app.bilibili.com/x/v2/view/like
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 说明 |
|------|------|
| `aid` | |
| `like` | `0` 点赞 / `1` 取消（与 Web 语义相反） |
| AppSign + access_key | 拦截器 |

### 点踩（App）

```
POST https://app.bilibili.com/x/v2/view/dislike
```

### 投币（Web · 实现用）

```
POST /x/web-interface/coin/add
```

| 参数 | 说明 |
|------|------|
| `aid` | ✓ |
| `multiply` | 1 或 2 |
| `select_like` | `0`/`1` 是否同时点赞 |
| `csrf` | ✓ |

### 投币（App）

```
POST https://app.bilibili.com/x/v2/view/coin/add
```

| 参数 | 说明 |
|------|------|
| `aid` | |
| `multiply` | 1 或 2 |
| `select_like` | `0`/`1` 是否同时点赞 |

### 一键三连 UGC

```
POST /x/web-interface/archive/like/triple
```

| 参数 | 说明 |
|------|------|
| `aid` | |
| `csrf` | ✓ |
| `eab_x`, `source`, `spmid`, `statistics`… | 客户端埋点 |

Headers：`origin`/`referer` 指向视频页，UA 用桌面浏览器更稳。

### 一键三连 PGC

```
POST /pgc/season/episode/like/triple
```

| 参数 | 说明 |
|------|------|
| `ep_id` | ✓ |
| `csrf` | ✓ |

### PGC 赞/币/藏状态

```
GET /pgc/season/episode/community?ep_id=
```

### 收藏视频

```
POST /x/v3/fav/resource/batch-deal
```

| 参数 | 说明 |
|------|------|
| `rid` | avid |
| `type` | `2` 视频 |
| `add_media_ids` | 收藏夹 id，逗号分隔 |
| `del_media_ids` | 取消的收藏夹 |
| `csrf` | ✓ |

另见 [fav.md](./fav.md)。

### 关注用户

```
POST /x/relation/modify
```

| 参数 | 说明 |
|------|------|
| `fid` | 目标 mid |
| `act` | 1关注 2取关 3悄悄关注 5拉黑 6取消拉黑… |
| `re_src` | 来源 |
| `csrf` | ✓ |

```
GET /x/relation?fid=
GET /x/relation/relations?fids= # 批量
```

### 追番

```
POST /pgc/web/follow/add # season_id, csrf
POST /pgc/web/follow/del
POST /pgc/web/follow/status/update
```

---

## 播放进度 / 历史上报

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/x/click-interface/web/heartbeat` | 播放心跳；`csrf`；未登录应跳过 |
| POST | `/x/v2/history/report` | 历史上报 aid/cid/progress |
| POST | `/x/v1/medialist/history` | 播单历史 |
| POST | live `roomEntryAction` | 进直播间 |

心跳常用字段：`aid`, `cid`, `mid`, `played_time`, `real_played_time`, `realtime`, `start_ts`, `type`, `dt`, `play_type`, `csrf` 等。

将这些接口路由到 `heartbeat` 账号槽。

---

## 笔记

```
GET /x/note/publish/list/archive # 稿件下笔记
GET /x/note/list
GET /x/note/publish/list/user
GET /x/note/list/archive
POST /x/note/add # csrf
POST /x/note/del
POST /x/note/publish/del
```

---

## 清晰度 qn 参考

| qn | 说明 |
|----|------|
| 16 | 360P |
| 32 | 480P |
| 64 | 720P |
| 80 | 1080P |
| 112 | 1080P+ |
| 116 | 1080P60 |
| 120 | 4K |
| 125 | HDR |
| 126 | 杜比视界 |
| 127 | 8K |
