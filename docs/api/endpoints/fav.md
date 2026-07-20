# 收藏 / 订阅 / 笔记端点

收藏夹、订阅与笔记。

Base：`https://api.bilibili.com` 
写操作均需 **Login + csrf**。

---

## 收藏夹

### 列表

```
GET /x/v3/fav/folder/created/list-all?up_mid=&type=2&rid=
GET /x/v3/fav/folder/created/list?pn=&ps=&up_mid=
GET /x/v3/fav/folder/info?media_id=
GET /x/v3/fav/folder/space?up_mid= # 他人公开收藏夹
GET /x/v3/fav/folder/collected/list # 我的订阅（播单等）
```

`list-all` 的 `rid` 可查询某稿件在哪些收藏夹。

### 内容

```
GET /x/v3/fav/resource/list
```

| 参数 | 说明 |
|------|------|
| `media_id` | 收藏夹 id |
| `pn`, `ps` | |
| `keyword` | 搜索 |
| `order` | `mtime`/`view`/`pubtime` |
| `type` | `0` 当前夹 `1` 全部 |
| `tid` | 分区 |
| `platform` | `web` |

### 增删改收藏夹

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/x/v3/fav/folder/add` | `title`,`intro`,`privacy`… |
| POST | `/x/v3/fav/folder/edit` | `media_id`+字段 |
| POST | `/x/v3/fav/folder/del` | `media_ids` |
| POST | `/x/v3/fav/folder/sort` | 排序；AppSign |
| POST | `/x/v3/fav/folder/fav` | 收藏他人收藏夹 |
| POST | `/x/v3/fav/folder/unfav` | 取消 |

### 资源操作

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/x/v3/fav/resource/batch-deal` | 批量加入/移出；`rid`,`type=2`,`add_media_ids`,`del_media_ids` |
| POST | `/x/v3/fav/resource/unfav-all` | 从所有夹取消 |
| POST | `/x/v3/fav/resource/copy` | 复制 |
| POST | `/x/v3/fav/resource/move` | 移动 |
| POST | `/x/v3/fav/resource/clean` | 清理失效 |
| POST | `/x/v3/fav/resource/sort` | 内容排序；AppSign |

---

## 合集订阅

```
POST /x/v3/fav/season/fav
POST /x/v3/fav/season/unfav
GET /x/space/fav/season/list?season_id=&pn=&ps=
```

---

## 追番列表

```
GET /x/space/bangumi/follow/list?type=1&pn=&ps=
```

`type`：1 追番 / 2 追剧 等。

---

## 课堂收藏

```
GET /pugv/app/web/favorite/page
POST /pugv/app/web/favorite/add
POST /pugv/app/web/favorite/del
```

---

## 话题收藏

```
GET /x/topic/web/fav/list
POST /x/topic/fav/sub/add
POST /x/topic/fav/sub/cancel
POST /x/topic/like
```

---

## 专栏收藏 / 图文

```
GET /x/polymer/web-dynamic/v1/opus/feed/fav
POST /x/article/favorites/add
POST /x/article/favorites/del
```

---

## 笔记

见 [video.md](./video.md#笔记)；用户侧列表：

```
GET /x/note/list
GET /x/note/publish/list/user
POST /x/note/del
POST /x/note/publish/del
```
