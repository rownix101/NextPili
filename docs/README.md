# NextPili Documentation

阅读与编写实现文档：先建立全局图，再跟 Guide 落地，查表进 Reference，外观与交互见 Human Interface。

写作要求见 [Documentation Style Pathway](./writing.md)：用语对齐 Apple Developer 气质，版式对齐 [Swift Pathway](https://developer.apple.com/cn/swift/get-started/)，**规则必须带可对照的 example**。

---

## Essentials

| 文档 | 说明 |
|------|------|
| [Architecture](./architecture.md) | 分层、依赖方向、ADR 与里程碑——系统如何拼在一起 |
| [Roadmap](./roadmap.md) | P0–P6 交付切片、验收标准与当前进度 |

Flutter 做薄壳；Rust 持有协议与凭据；`domain` 无 IO。

---

## Guides

模块怎么做：模型、边界、流程。文中步骤与约束应带 example。

| 文档 | 说明 |
|------|------|
| [Design Index](./design/README.md) | 模块地图与阅读顺序 |
| [domain](./design/domain.md) | ID、实体、错误与端口 |
| [ffi](./design/ffi.md) | FRB 边界、API 面、错误与事件 |
| [core](./design/core.md) | 用例编排与会话生命周期 |
| [auth](./design/auth.md) | 账号槽、Cookie、WBI、AppSign、登录流 |
| [http](./design/http.md) | 客户端栈、中间件、重试 |
| [media](./design/media.md) | 播放源、清晰度、弹幕规范化 |
| [store](./design/store.md) | 持久化 schema、加密、设置归属 |
| [flutter](./design/flutter.md) | 工程结构、Riverpod、路由 |

---

## Human Interface

长什么样、怎么操作。Token 与硬规则用具体值与 ✅/❌ 例子写清。

| 文档 | 说明 |
|------|------|
| [UX Index](./ux/README.md) | 设计规范地图与已锁定决策 |
| [Design System](./ux/design-system.md) | Liquid Glass、token、组件 |
| [Interaction](./ux/interaction.md) | 导航、指针/键盘、播放器、反馈 |
| [Motion](./ux/motion.md) | 时长、缓动、转场 |
| [Multi-platform](./ux/multi-platform.md) | 窗口、断点、输入设备 |
| [Copy](./ux/copy.md) | 产品文案：语气、按钮/空态/错误（Apple Writing 气质） |
| [Localization](./ux/localization.md) | ARB、复数、RTL、区域 |

---

## Reference

路径、参数、签名与响应形状。每个端点给最小成功 JSON；失败码尽量给例子。

| 文档 | 说明 |
|------|------|
| [API Index](./api/README.md) | 传输概览、约定、端点索引 |
| [Auth Overview](./api/auth/overview.md) | 域名、Cookie、Headers、槽位 |
| [WBI](./api/auth/wbi.md) · [AppSign](./api/auth/app-sign.md) · [gRPC](./api/auth/grpc.md) | 签名与帧格式 |
| [Endpoints](./api/README.md#端点) | 登录、视频、弹幕、搜索、用户等 |

---

## Style

| 文档 | 说明 |
|------|------|
| [Documentation Style Pathway](./writing.md) | 用语、Example-first、Pathway 式页面、变更纪律 |

---

## 阅读路径

### 工程新人

1. [Architecture](./architecture.md)  
2. [domain](./design/domain.md) + [ffi](./design/ffi.md)  
3. [auth](./design/auth.md) + [http](./design/http.md)  
4. 按任务进入 core / media / store / flutter  
5. 查表打开 [API](./api/README.md)

### UI / UX

1. [UX Index](./ux/README.md)  
2. [Design System](./ux/design-system.md)  
3. [Interaction](./ux/interaction.md) + [Motion](./ux/motion.md)  
4. [Copy](./ux/copy.md) + [Localization](./ux/localization.md)  
5. 工程落点：[flutter](./design/flutter.md)

### 协议回写

1. [API Index](./api/README.md)  
2. 对应 `api/auth/*` 或 `api/endpoints/*`（补全 request/response **example**）  
3. 若影响分层或错误模型 → 同步 architecture / design

---

## 维护

| 变更 | 写入 |
|------|------|
| 分层、ADR | `architecture.md` |
| 模块流程与例子 | `design/*` |
| 端点与响应例子 | `api/**` |
| 视觉 / 交互硬规则与 token 值 | `ux/*` |
| 产品界面用词与语气 | `ux/copy.md` |
| 用语、Pathway 版式与 Example-first | `writing.md` |

提交前过 [Style 自检清单](./writing.md#提交前自检)：无例子的步骤与契约视为未完成。
