# 当前用户 / 历史 / 稍后再看 / 关系

当前用户、历史、稍后再看与关系。

Base：`https://api.bilibili.com`（除非另注） 
多数接口需要 **Login**。

---

## 当前用户

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/x/web-interface/nav` | 导航栏用户信息 + wbi_img |
| GET | `/x/web-interface/nav/stat` | 关注/粉丝/动态数 |
| GET | `https://account.bilibili.com/site/getCoin` | 硬币数 |
| GET | `/x/relation/stat?vmid=` | 指定用户关系计数 |
| GET | `/x/member/web/coin/log` | 硬币流水 |
| GET | `/x/member/web/login/log` | 登录日志 |
| GET | `/x/member/web/exp/log` | 经验日志 |
| GET | `/x/member/web/moral/log` | 节操日志 |
| GET | `/x/member/app/up/realname` | 实名信息 |
| GET | `/x/vip/experience/add` | 领取大会员经验（若可用） |
| GET | `/x/space/setting/app` | 空间隐私设置 |
| POST | `/x/space/privacy/batch/modify` | 修改隐私；csrf |

---

## 历史记录

```
GET /x/web-interface/history/cursor
```

| 参数 | 说明 |
|------|------|
| `max` | 游标，首页 0 |
| `view_at` | 游标时间（秒） |
| `ps` | 每页（≤30） |
| `business` | 游标业务类型（与上一页 cursor 对齐） |
| `type` | 筛选：`all` / `archive` / … |

**Auth**：Cookie（SESSDATA） · Referer：`https://www.bilibili.com/account/history`

**成功 data（最小）**

```json
{
  "cursor": { "max": 123, "view_at": 1700000000, "business": "archive", "ps": 20 },
  "list": [
    {
      "title": "示例稿件",
      "cover": "https://i0.hdslb.com/bfs/archive/x.jpg",
      "author_name": "UP",
      "view_at": 1700000000,
      "progress": 30,
      "duration": 120,
      "kid": 42,
      "show_title": "P1",
      "history": {
        "oid": 42,
        "bvid": "BV1xx411c7mD",
        "cid": 99,
        "business": "archive",
        "page": 1
      }
    }
  ]
}
```

NextPili：`history_list` 仅保留可进详情的 `archive` / `pgc`；时间统一转毫秒。

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/x/v2/history/shadow/set` | 暂停/恢复记录；`switch` |
| GET | `/x/v2/history/shadow?jsonp=jsonp` | 是否暂停 |
| POST | `/x/v2/history/clear` | 清空；csrf |
| POST | `/x/v2/history/delete` | 删除；`kid` 列表；csrf |
| GET | `/x/web-interface/history/search` | 搜索历史；`keyword`,`pn` |

---

## 稍后再看

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/x/v2/history/toview/web` | 列表；`pn`,`ps`；可按未看/未看完筛选 |
| POST | `/x/v2/history/toview/add` | 添加；`aid` 或 `bvid`；csrf |
| POST | `/x/v2/history/toview/v2/dels` | 删除；`aids`；csrf |
| POST | `/x/v2/history/toview/clear` | 清空；`clean_type` 可选；csrf |
| POST | `/x/v2/history/toview/copy` | 复制到收藏夹等 |
| POST | `/x/v2/history/toview/move` | 移动 |

**`GET /x/v2/history/toview/web` 成功 data（最小）**

```json
{
  "count": 1,
  "list": [
    {
      "aid": 1,
      "bvid": "BV1xx411c7mD",
      "cid": 2,
      "title": "稍后再看示例",
      "pic": "https://i0.hdslb.com/bfs/archive/x.jpg",
      "duration": 90,
      "progress": 10,
      "add_at": 1700000000,
      "owner": { "mid": 1, "name": "UP", "face": "" }
    }
  ]
}
```

NextPili：`toview_list`（只读）；写操作后置 P6。

### 媒体列表（稍后再看/收藏夹资源）

```
GET /x/v2/medialist/resource/list
```

| 参数 | 说明 |
|------|------|
| `type` | 资源类型 |
| `biz_id` | |
| `oid` | 分页锚点 |
| `otype` | |
| `ps` | |
| `direction` | |
| `desc` | |

---

## 关注 / 粉丝 / 黑名单

### 关注列表

```
GET /x/relation/followings
```

| 参数 | 说明 |
|------|------|
| `vmid` | 用户 mid |
| `pn`, `ps` | ps≤50 |
| `order` | `desc` |
| `order_type` | 空=最近；`attention`=最常访问 |

```
GET /x/relation/followings/search # WBI；搜索关注
GET /x/relation/followings/followed_upper
GET /x/relation/same/followings
```

### 粉丝

```
GET /x/relation/fans?vmid=&pn=&ps=
```

### 黑名单

```
GET /x/relation/blacks
```

### 修改关系

见 [video.md](./video.md) `POST /x/relation/modify`。

### 关注分组（Tag）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/x/relation/tags` | 分组列表 |
| GET | `/x/relation/tag` | 分组内 UP；`tagid`,`pn` |
| POST | `/x/relation/tags/addUsers` | 设置用户分组；`fids`,`tagids`,csrf |
| POST | `/x/relation/tag/create` | 创建 |
| POST | `/x/relation/tag/update` | 改名 |
| POST | `/x/relation/tag/del` | 删除 |
| POST | `/x/relation/tags/update_sort` | 排序 |
| POST | `/x/relation/tag/special/add` | 特别关注 |
| POST | `/x/relation/tag/special/del` | 取消特别关注 |

---

## 举报用户

```
POST https://space.bilibili.com/ajax/report/add
```

表单字段以实现时抓包或联调为准。

---

## 预约

```
POST /x/space/reserve
POST /x/space/reserve/cancel
POST /x/dynamic/feed/reserve/click
GET /x/new-reserve/up/reserve/info
POST /x/new-reserve/up/reserve/create
POST /x/new-reserve/up/reserve/update
```
