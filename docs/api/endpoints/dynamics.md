# 动态 / 图文 / 话题 / 投票

动态流、发布、话题与投票。

Base：`https://api.bilibili.com`（除非另注）

动态 features 常量：

```text
itemOpusStyle,listOnlyfans,onlyfansQaCard
```

（完整列表见 `Constants.dynFeatures` 注释）

---

## 动态流

### 关注动态

```
GET /x/polymer/web-dynamic/v1/feed/all
```

| 参数 | 说明 |
|------|------|
| `type` | `all`/`video`/`pgc`/`article`… |
| `page` | |
| `offset` | 分页游标 |
| `host_mid` | 可选，某 UP |
| `timezone_offset` | `-480` |
| `features` | 见上 |

### 动态入口 / UP 列表

```
GET /x/polymer/web-dynamic/v1/portal
GET /x/polymer/web-dynamic/v1/uplist?offset=
GET /x/web-interface/dynamic/entrance # 未读动态数
```

### 动态详情

```
GET /x/polymer/web-dynamic/v1/detail?id=&features=
GET /x/polymer/web-dynamic/v1/detail/pic?id=
GET /x/polymer/web-dynamic/v1/detail/reaction
```

### 点赞动态

```
POST /x/dynamic/feed/dyn/thumb
```

| 参数 | 说明 |
|------|------|
| `dyn_id_str` / 相关 id | |
| `up` | 1 赞 / 2 取消 |
| `csrf` | ✓ |

### 置顶动态

```
POST /x/dynamic/feed/space/set_top
POST /x/dynamic/feed/space/rm_top
```

### 删除动态

```
POST /x/dynamic/feed/operate/remove
```

### 发布动态

```
POST /x/dynamic/feed/create/dyn
POST /x/dynamic/feed/edit/dyn
POST https://api.vc.bilibili.com/dynamic_svr/v1/dynamic_svr/create # 纯文本旧接口
```

创建接口 body 为复杂 JSON（内容节点、话题、@、投票、预约、图片 bfs 等）。

### 上传图片

```
POST /x/dynamic/feed/draw/upload_bfs # multipart
POST /x/upload/web/image # multipart
```

### 举报动态

```
POST /x/dynamic/feed/dynamic_report/add
```

### 私密可见设置

```
POST /x/dynamic/feed/dyn/private_pub_setting
```

---

## 图文 / 专栏

```
GET /x/article/viewinfo # WBI
GET /x/article/view # WBI 全文
GET /x/polymer/web-dynamic/v1/opus/detail # WBI 图文
GET /x/article/list/web/articles
POST /x/community/cosmo/interface/simple_action # 互动
```

---

## 话题

```
GET https://app.bilibili.com/x/topic/web/details/top
GET /x/polymer/web-dynamic/v1/feed/topic
GET /x/topic/web/details/fold
GET /x/topic/web/dynamic/rcmd
GET https://app.bilibili.com/x/topic/pub/search
```

收藏/点赞见 [fav.md](./fav.md)。

---

## 投票

```
GET /x/vote/vote_info?vote_id=
POST /x/vote/do_vote # csrf + body
POST /x/vote/create
POST /x/vote/update
GET https://api.vc.bilibili.com/vote_svr/v1/vote_svr/followee_votes
```

---

## @ 用户搜索（发动态）

```
GET /x/polymer/web-dynamic/v1/mention/search
```

---

## 气泡动态（tribee）

```
GET /x/tribee/v1/dyn/all
```
