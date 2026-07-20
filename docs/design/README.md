# 设计文档索引

> 上级：[Documentation](../README.md) · [架构总览](../architecture.md) · [API 约定](../api/README.md) · [UX](../ux/README.md)
> 写法：[Documentation Style Pathway](../writing.md)

本目录放 **模块级、可指导实现** 的设计，不重复架构总览中的 ADR 全文。

| 文档 | 内容 |
|------|------|
| [ffi.md](./ffi.md) | flutter_rust_bridge 边界、API 面、错误、事件、版本 |
| [core.md](./core.md) | 应用服务、会话生命周期、用例清单 |
| [domain.md](./domain.md) | 模型、ID、错误枚举、trait 端口 |
| [auth.md](./auth.md) | 账号、槽位、Cookie、WBI、AppSign、buvid、登录流 |
| [http.md](./http.md) | 客户端栈、中间件、端点模块划分、重试与日志 |
| [media.md](./media.md) | MediaSource、清晰度、音轨字幕、弹幕、播放器适配 |
| [store.md](./store.md) | 持久化 schema、加密、路径、设置归属 |
| [flutter.md](./flutter.md) | 目录、Riverpod、路由、feature 约定、`liquid_glass_widgets` 接入 |

## 阅读顺序（新人）

1. [architecture.md](../architecture.md) — 全局图  
2. [domain.md](./domain.md) + [ffi.md](./ffi.md) — 类型与边界  
3. [auth.md](./auth.md) + [http.md](./http.md) — 协议落地  
4. [core.md](./core.md) + [media.md](./media.md) + [store.md](./store.md)  
5. [flutter.md](./flutter.md) — UI 工程结构  
6. [ux/](../ux/README.md) — 视觉、交互、动效、多平台、本地化  
7. 按需查 [api/](../api/README.md) 端点表  

## 与 `docs/ux/` 的边界

| 目录 | 回答的问题 |
|------|------------|
| `docs/design/` | 模块怎么拆、API 怎么定、状态怎么管、存在哪 |
| `docs/ux/` | 长什么样、怎么操作、怎么动、多窗口/多语言怎么办 |

主题 token、Liquid Glass 材质、快捷键、断点等 **以 ux 为准**；`flutter.md` 只写目录、依赖接入与状态管理落点。

## 约定

- 设计变更若影响跨 crate 边界或 ADR，同步改 `architecture.md`。
- 端点字段变更只改 `docs/api/`，本目录只引用不复制参数表。
- 状态：各文首标注 `草案` / `已定`；未实现前默认草案。
