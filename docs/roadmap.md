# NextPili Roadmap

按垂直切片交付可演示能力：鉴权 → 浏览 → 播放 → 互动 → 个人库 → 扩展业务。阶段顺序与 [architecture §12](./architecture.md#12-mvp-落地顺序) 一致；用例名以 [design/core.md](./design/core.md) 为准。

> 状态：草案 v0.1  
> 当前进度：**P6 进行中**（写操作部分 + 动态只读 + 直播 REST + 番剧可播） · 下一目标：直播弹幕 WS / 多账号  
> 相关：[Architecture](./architecture.md) · [API](./api/README.md) · [Design](./design/README.md) · [UX](./ux/README.md)

---

## 1. 概览

| 阶段 | 主题 | 状态 | 一句话结果 |
|------|------|------|------------|
| **P0** | 骨架 | ✅ 完成 | Workspace + Flutter 壳 + FRB `ping` / `api_version` |
| **P1** | 鉴权 | ✅ 完成 | 短信/扫码登录、Cookie/WBI/AppSign、会话落盘 |
| **P2** | 浏览 | ✅ 完成 | 推荐/热门 feed + 稿件详情页 |
| **P3** | 播放 | ✅ 完成 | playurl → media_kit + 清晰度 + 心跳 + 设置 qn/代理 |
| **P4** | 互动只读 | ✅ 完成 | 评论列表 + 弹幕展示（REST） |
| **P5** | 个人库 | ✅ 完成 | 搜索 + 历史 / 稍后再看 / 收藏（只读） |
| **P6** | 扩展 | 🔶 进行中 | 写操作部分 ✅ · 动态 ✅ · 直播 REST ✅ · 番剧可播 ✅ · 直播 WS / 多账号 ⬜ |

**每阶段结束标准（通用）**

1. `cargo test --workspace` 绿  
2. 桌面端（至少 Linux）可演示该阶段路径  
3. 协议偏差回写 `docs/api/**`  
4. 新增 FRB API 已跑 `./scripts/codegen.sh`，边界符合 [design/ffi.md](./design/ffi.md)

**非目标（全程）**：服务端中继、插件市场、与官方 100% 行为一致、首期完整消息/商城。见 [architecture §1.3](./architecture.md#13-非目标当前阶段)。

---

## 2. 阶段详表

### P0 · 骨架 ✅

打通 Rust workspace、Flutter 桌面壳与 FRB 最小往返。

| 交付 | 落点 |
|------|------|
| Crate 边界 `domain` / `auth` / `http` / `store` / `media` / `core` | `crates/*` |
| FRB `ping` · `api_version` · `bootstrap` | `crates/core/src/api` |
| Flutter 壳、路由骨架 | `app/lib` · feature `shell` |

**验收**：应用启动 → FFI 调用成功；无真实 Cookie。

---

### P1 · 鉴权 ✅

协议与凭据全部在 Rust；Flutter 只驱动登录 UI。

| 交付 | 落点 |
|------|------|
| Cookie jar · buvid · WBI · AppSign · csrf 管线 | `auth` + `http` |
| 短信登录（captcha → send → sms） | core + Flutter `auth` |
| 桌面/平板 TV 扫码 | core + Flutter `auth` |
| 账号持久化（无 Cookie 粘贴导入） | `store` · `accounts.json` / `device.json` |
| 公开 `auth_state` / 账号列表 / 登出 | FRB |

**验收**：扫码或短信登录成功 → 冷启动仍登录 → 登出清会话。不落明文 Cookie 到 Flutter。

**用例**：[design/core.md §P1](./design/core.md#p1-鉴权) · 端点：[api/endpoints/login.md](./api/endpoints/login.md)

---

### P2 · 浏览 ✅

登录用户可刷推荐/热门，并打开稿件详情（尚不播放）。

| 交付 | Rust / API | Flutter |
|------|------------|---------|
| 推荐 feed（WBI · recommend 槽） | `feed_recommend` | feature `home` |
| 热门分页 | `feed_popular` | feature `home` |
| 稿件详情 + 分 P 列表 | `video_detail` | feature `video` |
| 错误态 / 未登录引导 | `AppError` 映射 | 空态与重试文案 |

**验收**

```text
登录 → 首页出现推荐卡片 → 点击进入详情（标题/UP/分P）→ 下拉刷新或换页不崩
```

**依赖**：P1 会话；[endpoints/video.md](./api/endpoints/video.md) 推荐/详情段。  
**UX**：桌面 NavigationRail + 内容区；卡片不玻璃化（[ux/design-system](./ux/design-system.md)）。

---

### P3 · 播放 ✅

从详情进入真实播放：取流、切换清晰度、心跳上报。

| 交付 | Rust / API | Flutter |
|------|------------|---------|
| playurl → `MediaSource` | `play_url` + `media` | feature `player` |
| media_kit 适配层 | DTO 不变 | `PlayerAdapter` |
| 清晰度切换 | qn / DASH 选择 | 播放器 chrome |
| 心跳 start/stop | `playback_*` · heartbeat 槽 | 进/出播放页 |
| 代理 / 默认 qn | `get_settings` / `update_settings` | feature `settings` |

**验收**

```text
详情 → 播放 → 出声出画 → 切换清晰度不断流 → 退出停止心跳
```

**依赖**：P2 详情 cid；[design/media.md](./design/media.md) · [endpoints/video.md](./api/endpoints/video.md) playurl。

---

### P4 · 互动只读 ✅

观看路径补全评论与弹幕（默认 REST；gRPC 随后）。

| 交付 | Rust / API | Flutter | 状态 |
|------|------------|---------|------|
| 评论分页 | `reply_list` | 详情 `ReplySection` | ✅ |
| 弹幕分段 → 时间轴条目 | `danmaku_segments` + `media` 规范化 | 播放器 `DanmakuOverlay` | ✅ |
| 弹幕性能基线 | 段内 cap 4000 · UI 同屏 48 | 开关按钮 | ✅ MVP |
| 楼中楼 / 发评论 / gRPC | — | — | ⬜ 后置（P4.1 / P6） |

**验收**

```text
播放中可见滚动弹幕；详情可翻评论；弱网有明确错误而非白屏
```

**依赖**：P3 播放时钟；[endpoints/reply.md](./api/endpoints/reply.md) · [danmaku.md](./api/endpoints/danmaku.md)。  
**决策**：P4 默认 HTTP；gRPC 评论翻译/DmSeg 记为 P4.1 或并入后续补丁（architecture 开放问题 #2）。

---

### P5 · 个人库 ✅

可找片、回看、管理稍后再看与收藏（只读为主）。

| 交付 | 用例方向 | Flutter | 状态 |
|------|----------|---------|------|
| 搜索（suggest + type=video，Gaia 后置） | `search_suggest` · `search_video` | feature `search` | ✅ |
| 观看历史 | `history_list` | feature `user` | ✅ |
| 稍后再看 | `toview_list` | feature `user` | ✅ |
| 收藏夹列表与内容（只读） | `fav_folders` · `fav_resources` | feature `user` | ✅ |

**验收**

```text
搜索进详情可播；历史/稍后再看/收藏列表可打开稿件
```

**依赖**：P2–P3；[endpoints/search.md](./api/endpoints/search.md) · [user.md](./api/endpoints/user.md) · [fav.md](./api/endpoints/fav.md)。

---

### P6 · 扩展与写操作 🔶

长尾业务与多账号路由；写操作在读路径稳定后开放。

| 交付 | 说明 | 状态 |
|------|------|------|
| 动态时间线（只读） | `dynamics_feed` · feature `dynamics` · [dynamics.md](./api/endpoints/dynamics.md) | ✅ |
| 直播（REST 可看） | `live_recommend` · `live_room` · `live_play_url` · feature `live` · [live.md](./api/endpoints/live.md) | ✅ |
| 直播弹幕 WS | `getDanmuInfo` + WSS 包头/心跳/解压（[live.md](./api/endpoints/live.md) §弹幕 WebSocket） | ⬜ |
| 番剧 / PGC | `pgc_rank` · `pgc_season` · `pgc_play_url` · feature `pgc` · [pgc.md](./api/endpoints/pgc.md) | ✅ |
| 多账号槽 | main / heartbeat / recommend / video 可绑不同账号 | ⬜ |
| 写操作 | 点赞 / 投币 / 默认收藏夹 / 长按选夹 / 关注 ✅ · 发弹幕 / 发评 / 三连 UI ⬜ | 部分 |

**验收**：「动态只读 + 一场直播可看 + 番剧排行→分集可播」已可演示；账号槽配置 UI / 写操作 / 直播弹幕可按子里程碑拆 PR。

**非首期**：完整私信/商城（[msg.md](./api/endpoints/msg.md) 可后置）。

---

## 3. 横切能力（穿插各阶段）

| 能力 | 最早插入 | 说明 |
|------|----------|------|
| 设置：代理 / 默认清晰度 | P3 | Rust store；UI 在 `settings` |
| 主题 / 玻璃画质偏好 | P1+ | 可先 Flutter 本地 |
| 多平台壳（平板 / 手机 / 折叠） | 桌面稳定后 | 断点见 [ux/multi-platform.md](./ux/multi-platform.md)；功能仍跟 P0–P6 |
| l10n ARB | P2 后 | MVP 可中文硬编码集中于 feature |
| gRPC 栈 | P4 后 | 帧格式见 [api/auth/grpc.md](./api/auth/grpc.md) |
| 发行与自动更新 | 非阻塞 | architecture 开放问题 #3 |
| CI：clippy · test · codegen diff | P0 起 | 禁止真实 Cookie |

---

## 4. 依赖与切片顺序

```text
P0 骨架
 └─ P1 鉴权 ─────────────────────────────┐
      └─ P2 浏览 ──┬─ P3 播放 ── P4 互动   │
                   └─ P5 个人库（可与 P4 并行启动搜索）
                        └─ P6 扩展 / 多账号 / 写
```

**建议并行**：P4 评论 与 P5 搜索可部分并行（不同 feature）；播放未稳前不开放写操作。

**Tracer bullet（优先打通）**

| 切片 | 路径 |
|------|------|
| 登录可演示 | 扫码 → 持久化 → 冷启动 |
| 看片主路径 | 推荐 → 详情 → 播放 → 弹幕 |
| 回访路径 | 搜索/历史 → 播放 |

---

## 5. 文档与代码同步纪律

| 变更类型 | 同步位置 |
|----------|----------|
| 阶段完成 / 范围调整 | 本文状态表 + 根 `README`「状态」段 |
| 分层 / ADR | [architecture.md](./architecture.md) |
| 用例与 DTO | [design/core.md](./design/core.md) · [ffi.md](./design/ffi.md) |
| 端点字段 | `docs/api/**`（带 example） |
| Feature 目录 | [design/flutter.md](./design/flutter.md) §7 |
| 视觉交互 | `docs/ux/*` |

实现顺序口诀：**先用例名与 DTO → 再 HTTP → 再 FRB codegen → 再 Flutter feature**。

---

## 6. 风险与缓冲

| 风险 | 阶段 | 缓解 |
|------|------|------|
| WBI / 接口变更 | 全程 | 契约测试 + `docs/api` 回写 |
| `-412` 风控 | P2+ | 完整 UA/buvid/代理；退避；多账号（P6） |
| 弹幕性能 | P4 | Rust 预处理、分页、UI 限流 |
| FRB / 桌面构建 | P0–P3 | 已通最小链路；播放器平台矩阵单独回归 |
| media_kit 平台差异 | P3 | 适配层隔离；Linux 优先验收 |

---

## 7. 版本与维护

| 版本 | 说明 |
|------|------|
| v0.1 | 初稿：对齐 architecture P0–P6；标注 P1 完成、P2 为当前目标 |

阶段完成时：把上表状态改为 ✅，并在根 `README` 更新「当前状态」一段。不在本文复制端点参数表——只链到 Reference。
