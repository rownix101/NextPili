# 媒体与播放设计（`media` + Flutter 适配）

> 状态：草案  
> 播放地址 API：[api/endpoints/video.md](../api/endpoints/video.md)  
> ADR-003：协议与播放器解耦

---

## 1. 职责划分

| 层 | 职责 |
|----|------|
| `http` | 请求 playurl（UGC/PGC/…），拿到原始 JSON |
| `media` | 解析为 `MediaSource`；清晰度/音轨选择；弹幕时间轴规范化 |
| `core` | 用例 `play_url` / 心跳；DTO 输出 |
| Flutter | `PlayerAdapter` + UI；默认 **media_kit (mpv)** |

`media` **不**链接 mpv，不渲染像素。

---

## 2. MediaSource 模型

```text
MediaSource {
  id: PlayId,              # aid/bvid + cid
  cid: Cid,
  format: Dash | FlvOrMp4Segments | Unknown,
  video_streams: [Stream],
  audio_streams: [Stream],  # 含多语言 / AI 音轨
  default_video: StreamId,
  default_audio: StreamId,
  duration_ms: i64,
  headers: Map<String, String>,  # 如 Referer, User-Agent
  subtitles: [SubtitleTrack],
  raw_quality_qn: Option<u32>,   # 请求时使用的 qn
}

Stream {
  id: StreamId,
  codec: String,           # avc1 / hev1 / av01 / mp4a ...
  bandwidth: u32,
  width, height, fps,      # video
  quality_label: String,   # 1080P60 等展示名
  qn: Option<u32>,
  language: Option<String>,
  role: Option<String>,    # 普通 / ai 等，按 API 字段映射
  url: String,             # 主 URL；备份 URL 列表可选
  backup_urls: [String],
}
```

字幕：

```text
SubtitleTrack {
  id, lang, label, url, format: Bbc | Ai | ...
}
```

---

## 3. playurl 规范化流程

```text
raw playurl response
  → 判断 dash / durl
  → 提取 video/audio 数组
  → 映射清晰度表（qn → 文案）
  → pick defaults（domain 策略 + 用户设置）
  → 附加播放 headers
  → MediaSource
```

### 3.1 默认清晰度策略

输入：`preferred_qn`、`max_qn`（会员能力）、`available`、`network_hint?`。

```text
1. 若 preferred 可用 → 选之
2. 否则 ≤ preferred 的最高
3. 否则 available 最低档（保证能播）
```

同 qn 多编码（DASH）：**可硬解优先**，硬解可用时 **AV1 > HEVC > AVC**；软解档整体低于任意可硬解档。

```text
例（AMD RX 5600：有 HEVC/AVC 硬解，无 AV1 硬解）
  同 1080P：hev1 → 选；av01 仅软解 → 排后

例（NVIDIA 5060+：AV1 硬解可用）
  同 1080P：av01 → 选
```

探测：`core` 启动时读 DRM/PCI（Linux）等得到 `HwDecodeCaps`，注入 `MediaService`。策略纯函数在 `domain::codec`。

音轨默认：`Dolby`（若有）→ `Hi-Res`（若有）→ 标准 192K / 最高标准档。播放器 UI **不展示**音轨菜单；杜比 / Hi-Res 激活时左下角短暂提示（彩虹渐变文案）。

### 3.2 Headers

B 站 CDN 常校验 Referer：

```text
Referer: https://www.bilibili.com
```

按实测补齐；放入 `MediaSource.headers`，由播放器适配层设置。

---

## 4. 弹幕

### 4.1 拉取

- 分段 API（见 `danmaku.md`）；`core.danmaku_segments(cid, segment_index)`。
- 解析后输出：

```text
DanmakuItem {
  progress_ms: i64,
  mode: i32,
  fontsize: i32,
  color: u32,
  text: String,
  mid_hash: String,
  id: i64,
  weight: i32,   // proto field 9; density cap prefers higher
}
```

拉取后：`merge_duplicate_danmaku`（同文案 100ms 窗合并，对齐 PiliPlus）→ `limit_danmaku`（weight 优先，默认 cap 4000）。

### 4.2 渲染（MVP）

- Flutter `Stack` + Overlay，按 `progress_ms` 与播放器 position 同步。
- **100ms 时间桶**索引（对齐 PiliPlus `progress ~/ 100`），避免每帧扫整段。
- 滚动轨 **避让**（同轨未出清不复用）；顶/底各少量固定轨。
- Seek 大跳（>|1s|）清空在屏与已 spawn 标记，避免漏弹/重弹。
- 在屏运动用 **播放时钟**（仅 `playing == true` 时累计 elapsed；倍速缩短 TTL），禁止纯墙钟驱动；暂停时冻结，恢复后连续。
- 限流：同屏上限、opacity；过高时丢弃。
- 发送：底栏输入 + `danmaku_post` + `injectLocal` 乐观上屏。
- **mode 7 高级弹幕**：`content` 为 JSON 数组（位置/透明度/时长/旋转），相对坐标绘制；解析失败则降级为普通滚动。
- 长按弹幕：点赞 / 举报（`danmaku_like` · `danmaku_report`）。
- 后期：评估 canvas / GPU / 播放器层弹幕。

### 4.3 字幕（含位置）

- 列表：`/x/player/wbi/v2` → `subtitle.subtitles`（优先 `subtitle_url`）。
- JSON body → WebVTT；`location` 2/默认底、5 顶，写出 VTT `line`/`position` 设置（高级位置字幕）。
- **渲染**：Flutter `SubtitleOverlay` 按 `position` 选中 cue；**不**经 media_kit `SubtitleTrack.data` / mpv `sub-add`（避免播放中断与临时文件无 `.vtt` 扩展导致加载失败）。

gRPC 弹幕：后续可选，同一 `DanmakuItem` 出口。

---

## 5. Flutter 播放器适配

```text
abstract class PlayerAdapter {
  Future<void> open(MediaSourceDto source);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration d);
  Future<void> setQuality(String streamId);
  Future<void> setAudio(String streamId);
  Stream<Duration> get position;
  Stream<PlayerState> get state;
  Future<void> dispose();
}

class MediaKitPlayerAdapter implements PlayerAdapter { ... }
```

### 5.1 media_kit 要点

- DASH：视频轨 + 音频轨 URL 组合（按插件 API 传双轨或 master）。
- 自定义 header：打开时传入 `MediaSource.headers`。
- 硬解：**全平台默认开启**（`enableHardwareAcceleration: true`，含 Linux）。依赖：`media_kit_video` ≥ 2.0.1（含 Linux Flutter 3.38+ H/W 修复）。若 Linux 仍出现「有声无画 / 纯色画面」（media-kit#1321 / #1404），可临时关硬解回退软解。
- **单一会话**：`PlaybackSession`（Riverpod）持有唯一 `MediaKitPlayerAdapter`。画面附着点在 `inline` / `fullscreen` / `mini` 间切换，**禁止**为全屏或小窗新建解码器。`fullscreen` 同时驱动 OS 窗口全屏（`DesktopOsFullscreen` / `window_manager`）；系统退出全屏时 host 回 `inline`。
- 生命周期：仅会话 `close()`（或应用退出）时 `dispose` 播放器并 `core.playback_stop()`。离开观看页且仍在播放 → 升为 `mini` 小窗，**保留进度与音频**。

### 5.2 清晰度切换

```text
UI 选择 → adapter 切流或
  重新 core.play_url(qn: new) → open 新 source（保留 position）
```

优先不重拉：若 `MediaSource` 已含多档 URL，本地切轨；否则重请求。

---

## 6. 心跳与进度

- `core.playback_start(PlayContext { aid, cid, ... })` 在 `open` 成功后调用。
- 进度 UI 仅用播放器 position；本地断点续播可每 N 秒 `store` 写一次（throttle）。
- 服务端历史上报在 Rust 心跳任务内完成。

---

## 7. 错误体验

| 情况 | 处理 |
|------|------|
| playurl 失败 | UI 错误页 + 重试；区分未登录/大会员/风控 |
| CDN 403 | 提示；尝试 backup_urls；刷新 playurl |
| 无音轨 | 仍播视频；提示 |
| 解码失败 | 降清晰度 / 换 codec 档 |

---

## 8. 测试

- `media`：fixture JSON → `MediaSource` 快照测。
- 策略函数：清晰度选择表驱动。
- 不在 CI 播真视频；E2E 手工。

---

## 9. 模块文件建议

```text
media/
  src/
    lib.rs
    source.rs       # MediaSource
    playurl.rs      # 解析 UGC/PGC
    quality.rs      # 或 re-export domain
    danmaku.rs
    subtitle.rs
```
