# 搜索端点

综合搜索、分类搜索与 Gaia 风控重试。

Base 默认：`https://api.bilibili.com` 
搜索站：`https://s.search.bilibili.com` 
App：`https://app.bilibili.com`

多账号：热搜/建议/推荐等走 `AccountType.recommend`（见 [auth/overview.md](../auth/overview.md#多账号策略)）。

---

## 热搜 / 建议 / 默认词

| 方法 | URL | 标记 | 说明 |
|------|-----|------|------|
| GET | `https://s.search.bilibili.com/main/hotword` | recommend | 热搜 |
| GET | `https://s.search.bilibili.com/main/suggest` | recommend | 搜索建议 |
| GET | `/x/web-interface/wbi/search/default` | WBI, recommend | 默认占位词 |
| GET | `/x/v2/search/trending/ranking` | recommend | 热搜榜 |
| GET | `https://app.bilibili.com/x/v2/search/recommend` | AppSign, recommend | App 搜索推荐 |

### 建议参数

```
GET https://s.search.bilibili.com/main/suggest?term=关键词&main_ver=v1&highlight=关键词
```

| 参数 | 说明 |
|------|------|
| `term` | ✓ 输入 |
| `main_ver` | `v1` |
| `highlight` | 常与 term 相同 |

响应可能是 **JSON 字符串**（非 object），需先 `json.decode`；成功时 `result` 为建议模型（注意不是 `data`）。

---

## 综合搜索

```
GET /x/web-interface/wbi/search/all/v2
```

| 参数 | 说明 |
|------|------|
| `keyword` | ✓ |
| `page` | |
| `order` | 排序（可选） |
| `duration` | 时长筛选 |
| `tids` | 分区 |
| `order_sort` | |
| `user_type` | |
| `category_id` | 专栏分类 |
| `pubtime_begin_s` / `pubtime_end_s` | 发布时间范围 |
| WBI | ✓ |

WBI 签名后 GET；`code==0` 时解析 `data`。

---

## 分类搜索

```
GET /x/web-interface/wbi/search/type
```

| 参数 | 说明 |
|------|------|
| `search_type` | 见下表 |
| `keyword` | ✓ |
| `page` | |
| `page_size` | 固定 `20` |
| `order` | `totalrank` / `click` / `pubdate` / `dm` / `stow`… |
| `duration` | 视频时长 |
| `tids` | 分区 |
| `order_sort` / `user_type` | |
| `category_id` | 专栏 |
| `pubtime_begin_s` / `pubtime_end_s` | |
| `platform` | `pc` |
| `web_location` | `1430654` |
| `gaia_vtoken` | 风控通过后带 |
| WBI | ✓ |

### search_type

| 值 | 含义 | 模型 |
|----|------|------|
| `video` | 视频 | `SearchVideoData` |
| `media_bangumi` | 番剧 | `SearchPgcData` |
| `media_ft` | 影视 | `SearchPgcData` |
| `live_room` | 直播间 | `SearchLiveData` |
| `bili_user` | 用户 | `SearchUserData` |
| `article` | 专栏 | `SearchArticleData` |

### 请求头（分类搜索）

```http
origin: https://search.bilibili.com
referer: https://search.bilibili.com/{search_type}?keyword={encoded}
Cookie: ...; x-bili-gaia-vtoken={gaiaVtoken} # 仅有 vtoken 时
```

### 风控 `v_voucher`

若 `data.v_voucher` 非空：

1. 触发 Gaia 人机验证（见 [misc.md](./misc.md#风控--人机验证gaia)）
2. 验证成功拿到 vtoken，重试搜索并带 `gaia_vtoken` + cookie

触发 Gaia 时走 `validate` 流程，并向 UI 返回「触发风控」。

---

## 稿件 id 转换

```
GET /x/player/pagelist?bvid= 或 aid=
```

| 用途 | 说明 |
|------|------|
| 取 `cid` | 多 P 时按 `part` 选页 |
| `dimension` | 宽高，播放器用 |

通过 `ab2c` / `ab2cWithDimension` 解析。

---

## 番剧 / 课堂季信息（搜索进详情）

```
GET /pgc/view/web/season?season_id= 或 ep_id=
GET /pugv/view/web/season?season_id=
GET /pgc/season/episode/web/info?ep_id=
```

注意 PGC 成功载荷常在 **`result`** 而非 `data`。完整追番/索引见 [pgc.md](./pgc.md)。

---

## 话题发布搜索

```
GET https://app.bilibili.com/x/topic/pub/search
```

发动态选话题时使用（App 域，常需 AppSign）。

---

## NextPili 建议

| 阶段 | 做法 |
|------|------|
| MVP | suggest + `search/type`（video）+ WBI |
| 完整 | all/v2、多 type、trending、Gaia 重试链路 |
| 账号 | 搜索可走 recommend 槽，与主账号浏览隔离 |
