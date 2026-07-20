# 鉴权与账号设计（`auth`）

> 状态：草案 
> API 细节：[api/auth/overview.md](../api/auth/overview.md)、[wbi.md](../api/auth/wbi.md)、[app-sign.md](../api/auth/app-sign.md)、[login.md](../api/endpoints/login.md)

---

## 1. 职责边界

| 在 `auth` | 不在 `auth` |
|-----------|-------------|
| Cookie jar 结构、按账号隔离 | 具体业务 path 列表的「业务含义」 |
| WBI 签名、AppSign、csrf 取值 | 发 HTTP（可被 `http` 调用） |
| buvid 生成算法 | 持久化 IO（接口由 store 实现，auth 定义需持久化的数据结构） |
| AccountSlot 路由表 | 登录 UI |

更干净的分法：`auth` 提供 **纯签名 + 账号模型**；`http` 中间件调用 `auth`；`store` 负责落盘。若实现时 `auth` 含少量「读 nav 接口刷新 WBI key」的回调，通过注入 `Fn` 避免循环依赖。

---

## 2. 账号模型

```text
Account {
 id: AccountId, // 本地主键
 mid: UserMid,
 name, face, // 可展示缓存
 cookie_jar: CookieJar, // SESSDATA, bili_jct, ...
 access_key: Option<String>,
 created_at, updated_at,
}

AccountRegistry {
 accounts: HashMap<AccountId, Account>,
 slots: EnumMap<AccountSlot, Option<AccountId>>,
 active_main: Option<AccountId>,
}
```

### 2.1 AccountSlot

| Slot | 用途 | 典型接口 |
|------|------|----------|
| `Main` | 默认写操作、用户信息 | 点赞、收藏、发评 |
| `Heartbeat` | 历史上报 / 心跳隔离 | heartbeat、history report |
| `Recommend` | 推荐污染隔离 | 首页推荐、热门、搜索 |
| `Video` | 播放地址隔离 | playurl 系 |

**单账号模式**：四槽同一 `AccountId`。 
**多账号模式**：用户在设置里把不同登录身份绑到不同槽。

解析请求账号：

```text
fn account_for(slot: AccountSlot) -> Option<&Account>
// 或
fn account_for_api(api: ApiKind) -> Option<&Account>
```

`ApiKind` 与 path 的映射表集中维护，避免散落 if-else。

---

## 3. Cookie

### 3.1 关键字段

`SESSDATA`、`bili_jct`、`DedeUserID`、`DedeUserID__ckMd5`、`sid`、`buvid3`、`buvid4`、`b_nut` …

- Domain：`.bilibili.com`
- jar 实现：可用 `reqwest_cookie_store` / 自研 map；需 **序列化** 到 store。

### 3.2 CSRF

```text
csrf = jar.get("bili_jct")
```

Web POST 表单字段名：`csrf` / 偶发 `biliCSRF` / `csrf_token`（按端点文档）。

### 3.3 写入来源

产品不提供「粘贴 Cookie」登录。Cookie jar 仅由 **短信 / 扫码等正规登录成功** 写入，并持久化到 store。

`CookieJar::parse_header` 仍可用于解析服务端 `cookie_info` / `Set-Cookie`，不对用户暴露导入 API。

---

## 4. buvid

- 未登录也必须有 `buvid3`（及需要时 `buvid4`）。
- 生成算法按约定格式生成（单测固定种子困难时测格式正则）。
- 激活：`POST .../ExClimbWuzhi`（见 overview）；失败不阻塞主流程，记日志。

存储：设备级 buvid 可全局一份，不绑账号；与账号 jar 合并发送。

---

## 5. WBI

流程（详见 api 文档）：

```text
1. 取 nav 中 wbi img/sub url → 抽 token
2. 混洗得 mixinKey（按日缓存）
3. 参数排序 + wts + 过滤字符 + mixin → md5 → w_rid
```

API：

```text
WbiSigner {
 cache: (date, mixin_key),
 async fn sign(&mut self, params: BTreeMap) -> BTreeMap // 注入 wts/w_rid
 async fn refresh_if_needed(&mut self, fetch_nav: impl Fn)
}
```

线程：签名本身 CPU 轻；refresh 需 HTTP，由 `http` 注入。

---

## 6. AppSign

```text
params + appkey + ts → 排序 → 拼接 appsec → md5 → sign
```

常量（HD 等）**集中**在 `auth::app_constants` 或配置，禁止业务文件硬编码。 
`access_key` 有则注入 query/body。

---

## 7. 登录流（TV 扫码 · 仅桌面/平板 UI）

```text
login_qr_start
 → GET/POST passport 申请二维码
 → 返回 { url, auth_code, expires_at }
 → 后台 task 轮询
 pending → QrLoginEvent::Scanned?
 confirm → 拉 Cookie / token → 写入 Account → AuthEvent::LoggedIn
 expire → QrLoginEvent::Expired

login_qr_cancel → abort task
```

轮询间隔：1.5–2s；超时后停。 
成功后：刷新 nav、确保 buvid、持久化。

---

## 8. 账号失效

触发：任意请求 `code == -101`，或主动校验失败。

```text
1. 标记 Account 失效（不清 secret 或按策略清）
2. EventBus: AuthEvent::Expired { account_id, mid }
3. Flutter 跳转登录 / 提示
```

自动用其它账号顶槽：**不做**（需用户显式配置），避免静默串号。

---

## 9. Headers 策略

由 `http` 中间件读取 `auth` 输出：

**Web 基线**：Cookie、Referer、`x-bili-mid`、`x-bili-aurora-eid`（由 mid 生成）等，见 overview。 
**App 基线**：UA BiliDroid HD、statistics、access_key+sign，无 Cookie 管理路径。

---

## 10. 测试向量

| 项 | 方法 |
|----|------|
| AppSign | 固定 appsec + params → 期望 sign |
| WBI | 固定 mixinKey + params → w_rid |
| csrf 注入 | jar 有 bili_jct 时表单含 csrf |
| Cookie 解析 | 多段字符串 |

禁止测试中打印真实 SESSDATA。

---

## 11. 模块文件建议

```text
auth/
 src/
 lib.rs
 account.rs # Account, Registry, Slot
 cookie.rs
 buvid.rs
 wbi.rs
 app_sign.rs
 csrf.rs
 constants.rs
 api_route.rs # ApiKind → Slot
```
