# NextPili

桌面端优先的 B 站第三方客户端骨架。

**技术栈**：Rust（协议 / 业务核心）+ Flutter（UI）+ [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 2.11。

## 架构

```text
Flutter (app/)  --FRB-->  core  --> domain
                              |--> auth / http / store / media
```

设计文档：

- [Documentation](docs/README.md) — 文档入口（Essentials / Guides / HIG / Reference）
- [架构总览](docs/architecture.md)
- [模块设计](docs/design/README.md)
- [API 约定](docs/api/README.md)
- [UX](docs/ux/README.md)
- [文档规范](docs/writing.md)

## 仓库布局

```text
NextPili/
├── crates/
│   ├── core/      # FFI + 用例编排
│   ├── domain/    # 纯领域（无 IO）
│   ├── auth/      # 账号 / Cookie / WBI / AppSign
│   ├── http/      # B 站 HTTP 客户端
│   ├── store/     # 本地持久化
│   └── media/     # 播放源规范化
├── app/           # Flutter 桌面壳
├── docs/
└── scripts/
```

## 开发环境

| 工具 | 版本建议 |
|------|----------|
| Rust | stable（edition 2021） |
| Flutter | ≥ 3.41（当前验证 3.44） |
| FRB codegen | `cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked` |
| cargo-expand | FRB 生成依赖 |

启用桌面：

```bash
flutter config --enable-linux-desktop
# windows / macos 同理
```

## 常用命令

```bash
# Rust 单测
cargo test --workspace
# 或
./scripts/test-rust.sh

# 重新生成 FRB 绑定（改 crates/core/src/api 后）
./scripts/codegen.sh

# Flutter
cd app
flutter pub get
flutter run -d linux
```

## P1 状态

已打通：

- Rust workspace 与 crate 边界
- `domain` / `auth` / `store` / `http` / `media` / `core`
- FRB：`ping` · `api_version` · `bootstrap` · 登录/账号 API
- 账号凭据持久化（登录成功写入 `accounts.json`，不提供 Cookie 粘贴导入）与设备 `buvid3`（`device.json`）
- WBI / AppSign 纯签名 + HTTP 请求管线（Cookie / csrf / 签名）
- 短信登录（captcha + sms/send + login/sms）与桌面/平板 TV 扫码
- Flutter 账号页（手机仅短信；桌面/平板额外扫码）

下一步（P2）：推荐/热门 feed、稿件详情、playurl → media_kit 播放。

## 许可

**非开源 / 仅审阅**（见根目录 [`LICENSE`](LICENSE)）。

- 允许：查看、阅读、审阅源码与文档；为学习与代码评审在本地克隆、浏览。
- 未授权：生产使用、修改后对外发布、再分发、商业利用等。
- 第三方依赖仍遵守各自原始许可。
- 应用分发请遵守 B 站服务条款与当地法律。

Cargo 元数据使用 `UNLICENSED`，表示未授予开源使用许可。
