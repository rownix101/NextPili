# NextPili

桌面端优先的 B 站第三方客户端骨架。

**技术栈**：Rust（协议 / 业务核心）+ Flutter（UI）+ [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) 2.11。

## 架构

```text
Flutter (app/)  --FRB-->  core  --> domain
                              |--> auth / http / store / media
```

设计文档：

- [架构总览](docs/architecture.md)
- [模块设计](docs/design/README.md)
- [API 约定](docs/api/README.md)
- [UX](docs/ux/README.md)

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

## P0 状态

已打通：

- Rust workspace 与 crate 边界
- `domain` / `auth` / `store` / `http` / `media` / `core` 骨架
- FRB：`ping` · `api_version` · `bootstrap`
- Flutter feature 目录、Riverpod、go_router 桌面壳

下一步（P1）：Cookie jar 持久化、buvid、WBI/AppSign、扫码登录。

## 许可

**非开源 / 仅审阅**（见根目录 [`LICENSE`](LICENSE)）。

- 允许：查看、阅读、审阅源码与文档；为学习与代码评审在本地克隆、浏览。
- 未授权：生产使用、修改后对外发布、再分发、商业利用等。
- 第三方依赖仍遵守各自原始许可。
- 应用分发请遵守 B 站服务条款与当地法律。

Cargo 元数据使用 `UNLICENSED`，表示未授予开源使用许可。
