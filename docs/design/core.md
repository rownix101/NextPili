# `core` 应用层设计

> 状态：草案  
> 依赖：`domain`、`auth`、`http`、`store`、`media`

---

## 1. 职责

`core` 是 **唯一** 对 Flutter（FRB）暴露的 Rust crate：

- 组装基础设施（客户端、存储、账号表）。
- 实现用例（use case），每个用例对应 1+ HTTP 调用与领域规则。
- 管理进程内会话与全局事件广播。
- 将 `domain::Error` 转为 `AppError`。

不负责：具体签名算法（`auth`）、具体 URL 拼装细节可下沉 `http`、UI。

---

## 2. 进程内结构

```text
CoreApp (Arc)
├── config: RuntimeConfig
├── store: Arc<dyn Store>          # 或具体 SqliteStore
├── accounts: AccountRegistry
├── http: BiliClient                # 持中间件
├── media: MediaService
├── events: EventBus
└── heartbeat: HeartbeatSupervisor  # 播放中上报
```

初始化：

```text
bootstrap(config)
  → open store(data_dir)
  → load accounts + jars
  → build BiliClient(proxy, ua)
  → ensure buvid
  → EventBus::emit(AuthSnapshot)
```

关闭：

```text
shutdown()
  → stop heartbeat
  → flush store
  → drop client
```

---

## 3. 用例清单（按 MVP）

### P1 鉴权

| 用例 | 行为摘要 |
|------|----------|
| `login_qr_start` | 申请 TV 二维码；返回 url + auth_code；内部开任务轮询 |
| `login_qr_cancel` | 取消轮询 |
| `login_captcha` / `login_sms_send` / `login_sms` | 短信登录/注册：极验 → 发码 → 校验（新号即建号） |
| `login_qr_*` | 仅桌面/平板 UI 暴露 |
| `logout` | 清指定账号或当前；可选调登出 API |
| `list_accounts` | 返回公开资料列表（无密钥） |
| `set_account_slot` | 绑定 AccountId → AccountSlot |
| `auth_state` | 当前是否登录、主账号 mid/昵称 |

### P2 浏览

| 用例 | 行为摘要 |
|------|----------|
| `feed_recommend` | recommend 槽 + WBI；过滤 `goto`；返回 DTO 列表 + next fresh_idx |
| `feed_popular` | 热门分页 |
| `video_detail` | aid/bvid → 详情 + 分 P |

### P3 播放

| 用例 | 行为摘要 |
|------|----------|
| `play_url` | video 槽；qn/fnval；`media` 规范化 → `MediaSourceDto` |
| `playback_start` | 注册心跳任务（cid、aid…） |
| `playback_stop` | 停止心跳 |
| `playback_progress` | 可选：本地进度落盘 |

### P4 互动只读

| 用例 | 行为摘要 |
|------|----------|
| `reply_list` | 分页评论 |
| `danmaku_segments` | 分段弹幕 → 结构化条目列表 |

### P5 个人库 ✅

| 用例 | 行为摘要 |
|------|----------|
| `search_suggest` | 搜索建议（recommend 槽） |
| `search_video` | 分类搜索 `type=video` + WBI |
| `history_list` | 观看历史 cursor（main 槽 · Cookie） |
| `toview_list` | 稍后再看分页 |
| `fav_folders` | 当前用户创建的收藏夹列表 |
| `fav_resources` | 收藏夹内容分页（只读） |

### P6 写操作（部分）+ 动态只读 + 直播 REST

| 用例 | 行为摘要 |
|------|----------|
| `video_relation` | 当前用户对稿件的赞/币/藏/关注态 |
| `video_like` | 点赞 / 取消 |
| `video_coin` | 投币（1–2）+ 可选同时点赞 |
| `video_favorite` | 默认收藏夹收藏 / 取消全部 |
| `video_favorite_deal` | 指定收藏夹批量加入 / 移出（长按选夹） |
| `fav_folders(rid)` | 可选 `rid=aid` 填充 `in_folder` |
| `relation_follow` | 关注 / 取关 UP |
| `dynamics_feed` | 关注动态时间线（offset 游标 · main 槽 · Cookie） |
| `live_recommend` | 直播推荐分页（可选登录） |
| `live_room` | 房间元数据（`getH5InfoByRoom`） |
| `live_play_url` | `getRoomPlayInfo`（WBI）→ `MediaSourceDto`（FLV/HLS） |
| `pgc_rank` | 番剧/影视排行（WBI · `season_type`） |
| `pgc_season` | `season_id` / `ep_id` → 详情 + 分集 |
| `pgc_play_url` | `/pgc/player/web/v2/playurl` → `result.video_info` → `MediaSourceDto` |

其余：直播弹幕 WS、多账号槽、楼中楼发评、发弹幕 → 继续按 `docs/api/endpoints` 逐项加，**先写用例名与 DTO 再实现 HTTP**。

---

## 4. 用例编写模板

```text
fn video_detail(id: VideoId) -> Result<VideoDetailDto, AppError>
  1. 解析 id（domain）
  2. http.video.detail(id, account=main 或默认读)
  3. map 响应 → domain → DTO
  4. map_err 到 AppError
```

规则：

- 用例函数 **薄**：复杂分支进 domain 纯函数或 `http` 模块。
- 不在用例里复制 WBI 细节。
- 需要的 `AccountSlot` 写在用例文档注释或路由表里，与 [auth.md](./auth.md) 一致。

---

## 5. 心跳督导

```text
playback_start(PlayContext)
  → HeartbeatSupervisor 以 interval 调用 http.heartbeat / history
  → 使用 AccountSlot::Heartbeat
  → 失败：tracing + 可选 Event（不打断播放）

playback_stop / 切换 cid
  → 取消旧任务
```

Flutter 只在「开始播放 / 暂停销毁 / 切 P」时调 start/stop；**不每秒过 FFI**。

---

## 6. 与 `http` 的边界

| 在 core | 在 http |
|---------|---------|
| 选哪个用例、槽位 | path、query、反序列化 raw |
| 聚合多次调用 | 单次请求 |
| DTO 输出 | 尽量 `domain` 类型或 raw + 转换 |

---

## 7. 测试

- `CoreApp` 可用 mock `BiliClient` trait 注入（若抽 port）。
- 初期可 `#[cfg(test)]` 替换 base URL 为 wiremock。
- 每个用例至少：成功路径 + 未登录 + 业务 code 非 0。
