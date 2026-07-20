# NextPili

[![License](https://img.shields.io/badge/license-Review--Only-red)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-edition%202024-orange?logo=rust)](https://www.rust-lang.org/)
[![MSRV](https://img.shields.io/badge/MSRV-1.85-orange?logo=rust)](https://www.rust-lang.org/)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![FRB](https://img.shields.io/badge/flutter__rust__bridge-2.12-blue)](https://github.com/fzyzcjy/flutter_rust_bridge)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)](#)

用 Rust 持有协议与凭据、用 Flutter 做桌面壳，经 [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 2.12 贯通的 B 站第三方客户端骨架。

> **Important:** 本仓库为 **审阅专用 / 非开源**。允许本地克隆阅读；禁止未授权的生产使用、再分发与商业利用。完整条款见 [LICENSE](LICENSE)。

## 概览

NextPili 是桌面优先（Linux / Windows / macOS）的 B 站客户端工程。业务与签名在 Rust；UI 只做展示与交互。`domain` 无 IO；凭据不得进入 Flutter 持久化层。

| 层 | 职责 |
|----|------|
| `app/` | Flutter 壳：路由、页面、播放器表面 |
| `core` | FRB 面与用例编排 |
| `auth` / `http` / `store` / `media` | 协议、请求、持久化、播放源规范化 |
| `domain` | 共享模型与错误语义（无 IO） |

```text
Flutter (app/)  --FRB-->  core  --> domain
                              |--> auth / http / store / media
```

请求从 Flutter 经 `core` 进入业务 crate；网络、鉴权与凭据读写都在 Rust。

## 文档

权威入口：[Documentation](docs/README.md)。实现契约与进度只在 `docs/` 定义；本页不复制全文。

| 文档 | 说明 |
|------|------|
| [Architecture](docs/architecture.md) | 建立分层、依赖方向与 ADR |
| [Roadmap](docs/roadmap.md) | 查 P0–P6 交付切片与验收 |
| [Design Index](docs/design/README.md) | 按模块落地实现边界 |
| [API Index](docs/api/README.md) | 查路径、签名与响应形状 |
| [UX Index](docs/ux/README.md) | 对齐外观、交互与 token |
| [Documentation Style](docs/writing.md) | 写文档时的用语与 Example-first 要求 |

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
├── docs/          # Essentials / Guides / HIG / Reference
└── scripts/       # 测试与 FRB codegen
```

用 `crates/*` 按职责切边界；改 `crates/core/src/api` 后跑 `scripts/codegen.sh`。

## 构建环境

| 工具 | 要求 |
|------|------|
| Rust | stable，edition 2024，MSRV 1.85 |
| Flutter | ≥ 3.41（当前验证 3.44） |
| FRB codegen | `flutter_rust_bridge_codegen` 2.12.0（`--locked`） |
| cargo-expand | FRB 生成依赖 |

启用桌面目标：

```bash
flutter config --enable-linux-desktop
# windows / macos 同理
```

把 Flutter 目标打开到 Linux / Windows / macOS，再在 `app/` 下运行。

**Linux 桌面穿透 / blur：** 壳层透明后，live blur 依赖合成器协议 `ext-background-effect-v1`（runner：`desktop_compositor_blur.cc`）。**GNOME/Mutter 预计 ≥51** 才支持；50.x 上只有透明、无模糊是预期行为。KWin（Plasma 6.7+）、Hyprland、Niri 等已实现该协议的环境可测 live blur。自检：`wayland-info | grep background_effect`。

安装 FRB 代码生成器：

```bash
cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
```

## 常用命令

运行 Rust 工作区测试：

```bash
cargo test --workspace
# 或
./scripts/test-rust.sh
```

修改 `crates/core/src/api` 后重新生成 FRB 绑定：

```bash
./scripts/codegen.sh
```

启动 Flutter 桌面壳（以 Linux 为例）：

```bash
cd app
flutter pub get
flutter run -d linux
```

## 当前进度

**P0–P5 已完成**；**P6 进行中**（写操作部分 + 动态 + 直播 REST + 番剧可播已交付；直播弹幕 WS / 多账号待办）。切片与验收以 [Roadmap](docs/roadmap.md) 为准。

已打通（摘要）：

- Workspace 与 crate 边界：`domain` / `auth` / `store` / `http` / `media` / `core`
- FRB：`ping` · `api_version` · `bootstrap` · 登录/账号 / feed / video / play_url / settings / search / library
- 账号持久化（`accounts.json`，无 Cookie 粘贴导入）与 `buvid3`（`device.json`）
- WBI / AppSign 与 HTTP 管线（Cookie / CSRF / 签名）
- 短信登录与桌面/平板 TV 扫码；推荐/热门/详情；playurl → media_kit 播放与清晰度
- 评论 + 弹幕 Overlay（REST）；搜索；历史 / 稍后再看 / 收藏只读
- 设置：`preferred_qn` / 代理（Rust store，热更新 HTTP 客户端）

## 许可

本作品 **不是** OSI 开源软件。Cargo 元数据为 `UNLICENSED`。

| | 范围 |
|--|------|
| **允许** | 查看、阅读、审阅；为学习与代码评审在本地克隆、浏览 |
| **禁止（未授权时）** | 生产使用、对外发布修改版、再分发、商业利用 |
| **第三方** | 各依赖仍遵守其原始许可 |
| **应用分发** | 须遵守 B 站服务条款与适用法律 |

完整条款见 [LICENSE](LICENSE)。

## See Also

- [Documentation Home](docs/README.md)
- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [LICENSE](LICENSE)
