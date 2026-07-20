# 用户空间（Member）端点

用户空间、投稿与关注分组。

---

## 用户资料

### Web WBI 资料

```
GET /x/space/wbi/acc/info
```

| 参数 | 说明 |
|------|------|
| `mid` | ✓ |
| `token` | 可空 |
| `platform` | `web` |
| `web_location` | |
| `dm_img_*` | 与 playurl 类似的风控字段（建议携带） |
| WBI | ✓ |

### 名片

```
GET /x/web-interface/card?mid=&photo=true
```

### App 空间聚合

```
GET https://app.bilibili.com/x/v2/space
```

AppSign + 常见 app 参数 + `vmid`。

### 关系统计 / 播放获赞

```
GET /x/relation/stat?vmid=
GET /x/space/upstat?mid=
```

---

## 投稿

### Web 搜索投稿

```
GET /x/space/wbi/arc/search
```

| 参数 | 说明 |
|------|------|
| `mid` | ✓ |
| `ps`, `pn` | |
| `tid` | 分区 0=全部 |
| `keyword` | |
| `order` | `pubdate`/`click`/`stow`… |
| `platform` | `web` |
| WBI | ✓ |

### App 游标投稿

```
GET https://app.bilibili.com/x/v2/space/archive/cursor
GET https://app.bilibili.com/x/v2/space/archive/charging # 充电专属
```

### 合集 / 列表

```
GET https://app.bilibili.com/x/v2/space/season/videos
GET https://app.bilibili.com/x/v2/space/series
GET /x/polymer/web-space/seasons_series_list
GET /x/polymer/web-space/home/seasons_series
GET /x/polymer/web-space/seasons_archives_list
GET /x/series/archives
```

### 其它空间内容

| 路径 | 说明 |
|------|------|
| `https://app.bilibili.com/x/v2/space/bangumi` | 追番 |
| `https://app.bilibili.com/x/v2/space/article` | 专栏 |
| `https://app.bilibili.com/x/v2/space/comic` | 漫画 |
| `/audio/music-service/web/song/upper` | 音频 |
| `/pugv/app/web/season/page` | 课堂 |
| `/x/v3/fav/folder/space` | 公开收藏夹 |
| `/x/polymer/web-dynamic/v1/opus/feed/space` | 图文 |
| `/x/space/top/arc` | 置顶视频 |
| `/x/space/coin/video` | 最近投币 |
| `/x/space/like/video` | 最近点赞 |
| `https://app.bilibili.com/x/v2/space/coinarc` | App 投币稿件 |
| `https://app.bilibili.com/x/v2/space/likearc` | App 点赞稿件 |
| mall `community-hub/small_shop/...` | 小店 |

---

## 空间动态

```
GET /x/polymer/web-dynamic/v1/feed/space
```

| 参数 | 说明 |
|------|------|
| `host_mid` | ✓ |
| `offset` | 分页 |
| `timezone_offset` | `-480` |
| `features` | 见动态文档 |
| WBI | 需要签名 |

```
GET /x/polymer/web-dynamic/v1/feed/space/search
```

`keyword` + `host_mid` 等。

---

## 充电榜 / 大航海

```
GET /x/upower/up/member/rank/v2
GET https://api.live.bilibili.com/xlive/app-ucenter/v1/guard/MainGuardCardAll
GET https://api.live.bilibili.com/xlive/web-ucenter/user/MedalWall
```
