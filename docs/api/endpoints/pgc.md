# 番剧 / 影视 / 课堂 (PGC / PUGV)

番剧、影视与课堂。

Base：`https://api.bilibili.com`

> **响应约定**：大量 PGC 接口成功载荷在 **`result`**（不是 `data`）。 
> 播放地址 `/pgc/player/web/v2/playurl` 亦常为 `result.video_info` 嵌套，解析时勿硬套 UGC 的 `data`。

### NextPili 已实现（P6）

| 用例 | 端点 | 说明 |
|------|------|------|
| `pgc_rank` | `GET /pgc/web/rank/list` | WBI；`season_type` + `day` |
| `pgc_season` | `GET /pgc/view/web/season` | `season_id` 或 `ep_id`；payload 在 `result` |
| `pgc_play_url` | `GET /pgc/player/web/v2/playurl` | `ep_id` + `cid`；取 `result.video_info` → 与 UGC 相同 DASH 解析 |

---

## 详情

```
GET /pgc/view/web/season?season_id= 或 ep_id=
GET /pugv/view/web/season?season_id=
GET /pgc/season/episode/web/info?ep_id=
GET /pgc/view/web/season/user/status?season_id= # 追番状态
```

播放地址见 [video.md](./video.md#播放地址)：

```
GET /pgc/player/web/v2/playurl
GET /pugv/player/web/playurl
```

---

## 索引 / 时间表

```
GET /pgc/season/index/condition # 筛选项；season_type 等
GET /pgc/season/index/result # 索引结果；分页+筛选
GET /pgc/web/timeline # 时间表；types, before, after
```

---

## 排行

```
GET /pgc/web/rank/list # WBI
GET /pgc/season/rank/web/list # WBI
```

---

## 追番操作

```
POST /pgc/web/follow/add # season_id, csrf
POST /pgc/web/follow/del
POST /pgc/web/follow/status/update
GET /x/space/bangumi/follow/list
```

---

## 短评 / 长评

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/pgc/review/long/list` | 长评 |
| GET | `/pgc/review/short/list` | 短评 |
| POST | `/pgc/review/action/like` | 赞 |
| POST | `/pgc/review/action/dislike` | 踩 |
| POST | `/pgc/review/short/post` | 发短评 |
| POST | `/pgc/review/short/modify` | 改 |
| POST | `/pgc/review/short/del` | 删 |

---

## 课堂收藏

见 [fav.md](./fav.md#课堂收藏)。

---

## 互动（PGC）

```
GET /pgc/season/episode/community?ep_id=
POST /pgc/season/episode/like/triple
```
