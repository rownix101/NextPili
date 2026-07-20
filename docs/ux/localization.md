# 本地化与国际化（i18n / l10n）

> 状态：草案 v0.1  
> 依赖：[UX 索引](./README.md) · [设计规范](./design-system.md) · [多平台](./multi-platform.md)  
> 参考：[Flutter Internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)

本文约定文案、区域格式、RTL 与翻译工作流。NextPili 面向中文用户为主，但 **工程从第一天按可本地化搭建**，避免硬编码中文渗透业务层。

---

## 1. 目标

| 项 | 约定 |
|----|------|
| 默认语言 | 简体中文（`zh` / `zh_CN`） |
| 首期交付语言 | 简体中文；可选同步英文骨架（便于审文档与贡献） |
| 后续语言 | 繁体中文、英文等按社区需求 |
| 区域格式 | 日期、数字、列表缩写跟随 locale |
| RTL | 架构支持；首期可不提供 RTL 语言，但布局用逻辑方向属性 |

---

## 2. 技术栈（Flutter）

- `flutter_localizations` + `intl`
- 官方 **gen-l10n**：ARB → `AppLocalizations`
- 配置示例（实现时落地）：

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
preferred-supported-locales: [ zh ]
```

```yaml
# pubspec.yaml
flutter:
  generate: true
```

- `MaterialApp`：
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`
  - `supportedLocales: AppLocalizations.supportedLocales`
  - `locale` / `localeResolutionCallback`：支持「跟随系统」与用户覆盖

Rust 层错误信息：返回 **稳定错误码 + 可选服务端消息**；Flutter 将码映射为本地化文案。不在 Rust 拼用户可见长句（开发日志除外）。

---

## 3. 文案规范

### 3.1 禁止硬编码

- UI 可见字符串必须来自 l10n（调试 `debugPrint` 除外）。
- 包括：按钮、标题、Tooltip、空状态、权限说明、SnackBar、设置项、无障碍 label。

### 3.2 ARB 键名

- 使用 **lowerCamelCase** 语义键：`searchHint`、`playerPlay`、`errorNetworkRetry`。
- 按功能前缀分组（可选）：`player*`、`settings*`、`auth*`。
- 每个 key 提供 `@key.description`，供译者理解语境。

### 3.3 插值、复数、选择

- 占位符：`"welcome": "你好，{name}"`
- 复数：使用 ICU `plural`（播放量、评论数等）
- 选择：性别等少见；状态枚举优先在 Dart 侧选不同 key，避免译者难懂的复杂 select

### 3.4 语气与用语

| 场景 | 建议 |
|------|------|
| 按钮 | 动词短句：「登录」「重试」「发送」 |
| 错误 | 说明原因 + 可执行下一步：「网络不可用，请检查后重试」 |
| 危险 | 明确后果：「退出后将无法同步收藏」 |
| 幽默 | 克制；空状态可轻度，错误态保持严肃清晰 |

B 站特有词（弹幕、UP 主、硬币、番剧、分 P）在中文内保留社区习惯；英文稿使用通行译法并在 glossary 固定。

### 3.5 术语表（节选，可扩展）

| 中文 | English（建议） | 备注 |
|------|-----------------|------|
| 弹幕 | Danmaku / Comments overlay | 产品内可保留 Danmaku |
| UP 主 | Uploader / Creator | |
| 分 P | Part | 多段视频 |
| 稍后再看 | Watch later | |
| 清晰度 | Quality | |
| 硬币 | Coin | 平台货币，慎译 |
| 番剧 | PGC / Anime & Series | |
| 动态 | Feed / Dynamics | |

---

## 4. 数字、日期与计量

### 4.1 数字缩写（内容数据）

B 站数据常需缩写，**按 locale 分支**：

| locale | 示例 |
|--------|------|
| zh_* | `999`、`1.2万`、`3.4亿` |
| en_* | `999`、`1.2K`、`3.4M`、`1.2B` |

实现：独立 `formatCount(locale, n)`，不要在 Widget 里写死「万」。

### 4.2 时长

- 进度/总长：`m:ss` / `h:mm:ss`，**等宽数字**。
- 不随 locale 改成文字「分/秒」在进度条上（易抖）；文字描述场景可用本地化（「约 3 分钟」）。

### 4.3 日期时间

- 使用 `intl` `DateFormat` 与 locale 同步。
- 相对时间：「刚刚」「3 分钟前」「昨天」——各语言单独规则或成熟库；中文优先社区习惯。

### 4.4 列表排序与校对

- 中文排序若涉及 locale Collator，后续再定；首期服务端顺序为主。

---

## 5. 布局与 RTL

### 5.1 规则

- 使用 **逻辑属性**：`EdgeInsetsDirectional`、`AlignmentDirectional`、`TextAlign.start`。
- 返回箭头、Rail 位置、抽屉边缘随 `Directionality` 镜像。
- **进度条时间轴**：通常保持时间从左到右（媒体惯例）；若 RTL 语言需要，再评估是否镜像 seek 条（建议播放器时间轴 **不镜像**，与主流视频站一致）。
- 弹幕方向：原数据方向为主；RTL 界面下仍按弹幕协议绘制。

### 5.2 文案扩展

- 德语/英文通常比中文长：**按钮 min width 不写死汉字数**；`Flexible`/`Expanded` 包标签。
- Rail 标签：允许两行或缩写策略；tooltip 显示全名。
- 截图与验收用最长语言压布局（若仅有中文，用人为加长伪语言 `zz` 测试——可选）。

---

## 6. 图片与区域内容

- 封面、远程文案随 API；应用不二次翻译 UGC。
- 应用内插图若含文字：提供多语言资源或改为无字插图 + l10n 标题。
- 外链与帮助文档：按语言切换 URL（若有）。

---

## 7. 语言切换

| 模式 | 行为 |
|------|------|
| 跟随系统（默认） | `locale: null`，走系统解析 |
| 用户固定 | 设置中保存 `zh` / `en` / … 写入非敏感偏好 |
| 即时生效 | 改 locale 后全应用 rebuild；播放中不中断播放 |

iOS/macOS：在 Runner 工程声明支持的语言列表，便于系统设置展示。

---

## 8. 无障碍与本地化交叉

- `Semantics` label 全部走 l10n。
- 屏幕阅读器语序检查：拼接字符串用 ARB 整句，避免「字符串碎片」语序错误。
- 正确示例：`"likedBy": "{name} 赞了你的评论"`  
  错误示例：`l10n.liked + name + l10n.yourComment`

---

## 9. 错误码映射

```text
Rust AppError.kind  →  Flutter 枚举  →  l10n.errorXxx
可选 bili_code / message → 调试详情（高级/日志），默认用户可见用本地化模板
```

用户可见层：**不直接展示**原始 HTTP body 或堆栈。

---

## 10. 工作流

1. 开发新增 UI 文案 → 写入模板 ARB（`app_zh.arb`）+ description。  
2. `flutter gen-l10n` 生成 getter。  
3. 其他语言 ARB 同步 key；CI 可校验 **缺译**（`untranslated-messages-file`）。  
4. 产品/译者审术语表。  
5. 截图验收各语言关键页。

### 10.1 目录建议

```text
app/lib/l10n/
  app_zh.arb          # 模板（或 app_en.arb 作模板，按团队习惯）
  app_en.arb
  app_zh_Hant.arb     # 可选繁体
```

---

## 11. 首期范围
| 做 | 不做（首期） |
|----|----------------|
| 全 UI 中文 ARB 化 | 完整社区翻译平台 |
| 跟随系统 + 应用内切换架构 | 多语言运营文案 CMS |
| 数字缩写/时长格式工具 | 服务端 UGC 翻译 |
| 逻辑方向布局习惯 | 完整 RTL 视觉验收（无 RTL 语言时） |

---

## 12. 验收清单（本地化）

- [ ] 业务 UI 无硬编码用户可见中文/英文
- [ ] 切换语言后设置项、播放器控件、错误提示均变化
- [ ] 复数/大数缩写在 zh/en 表现正确
- [ ] 登录门闸与空状态文案完整
- [ ] 错误码有对应本地化，无原始堆栈直接展示
- [ ] 布局在长字符串下无严重溢出（常见按钮/Rail）
