# 登录 / 鉴权端点

登录、登出与设备管理。

Base：`https://passport.bilibili.com`（除非另注）

标记：`AppSign` = 需要 App 签名；`Login` = 需要登录 Cookie

---

## 推荐登录方式（MVP）

### 1. TV / HD 扫码登录（首选）

流程：

```text
getTVCode → 展示 url/二维码 → 轮询 qrcodePoll → 拿到 token + cookie
```

#### 申请二维码

```
POST /x/passport-tv-login/qrcode/auth_code
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `local_id` | ✓ | 可用 `"0"` |
| `platform` | ✓ | `android` |
| `mobi_app` | ✓ | `android_hd` |
| `appkey`/`ts`/`sign` | ✓ | AppSign |

成功 `data`：

| 字段 | 说明 |
|------|------|
| `auth_code` | 轮询用 |
| `url` | 二维码内容 URL |

#### 轮询扫码结果

```
POST /x/passport-tv-login/qrcode/poll
```

| 参数 | 必要 | 说明 |
|------|------|------|
| `auth_code` | ✓ | 上一步 |
| `local_id` | ✓ | `"0"` |
| AppSign | ✓ | |

`code`：

| code | 含义 |
|------|------|
| 0 | 成功，`data` 含 token / cookie 信息 |
| 86039 | 未扫码 |
| 86090 | 已扫码未确认 |
| 86038 | 二维码失效 |

成功后保存：`access_key`、cookie（`SESSDATA` 等）、`refresh_token`（若有）。

---

### 2. 短信登录（App，手机端首选）

```
GET /x/passport-login/captcha?source=main_web
POST /x/passport-login/sms/send   # AppSign + 极验结果
POST /x/passport-login/login/sms  # AppSign
```

客户端策略：

- **手机**：短信 + 密码
- **桌面 / 平板**：短信 + 密码 + TV/HD 扫码
- **不提供** Cookie 粘贴导入 UI（登录成功后的 jar 仍由 Rust 持久化）

`cid` 为中国大陆时使用护照国家列表 **id=1**（不是拨号 86）。

---

### 3. 密码登录（App）

```
GET /x/passport-login/web/key # 拿 salt + RSA 公钥
POST /x/passport-login/oauth2/login # AppSign + 极验
```

密码加密：`RSA_encrypt(hash + password)` → Base64。

**风控二次验证（对齐 PiliPlus）**，当 `data.status == 2` 且 `data.url` 含 `tmp_token` / `request_id` / `source`：

```text
1. GET  /x/safecenter/user/info?tmp_code=<tmp_token>     → hide_tel
2. POST /x/safecenter/captcha/pre                        → gee_gt / challenge / recaptcha_token
3. 完成极验
4. POST /x/safecenter/common/sms/send  AppSign           → captcha_key（Referer=risk url）
5. POST /x/safecenter/login/tel/verify AppSign           → oauth code
6. POST /x/passport-login/oauth2/access_token AppSign    → token_info + cookie_info
```

---

### 4. 短信登录（App）

```
GET /x/passport-login/captcha?source=main_web # 极验参数
POST /x/passport-login/sms/send # 发短信 AppSign
POST /x/passport-login/login/sms # 登录 AppSign
```

发短信关键参数：

| 参数 | 说明 |
|------|------|
| `cid` | 国际区号，中国 `86` |
| `tel` | 手机号 |
| `buvid` / `local_id` | 设备 id |
| `login_session_id` | `md5(buvid + timestamp_ms)` |
| `gee_*` / `recaptcha_token` | 人机验证结果 |
| `build`, `mobi_app`, `platform`, `statistics` | 客户端信息 |

---

## 其它登录相关

| 方法 | 路径 | 标记 | 说明 |
|------|------|------|------|
| GET | `/x/passport-login/captcha?source=main_web` | | Web 验证码/极验 |
| GET | `/x/passport-login/web/key` | | RSA 公钥 + hash |
| POST | `/x/passport-login/web/sms/send` | | Web 发短信 |
| POST | `/x/passport-login/web/login` | | Web 密码登录 |
| GET | `/x/safecenter/user/info` | | 风控用户信息（`tmp_code`） |
| POST | `/x/safecenter/captcha/pre` | | 风控前人机 |
| POST | `/x/safecenter/common/sms/send` | AppSign | 风控短信 |
| POST | `/x/safecenter/login/tel/verify` | AppSign | 风控短信校验 |
| POST | `/x/passport-login/oauth2/access_token` | AppSign | 换 access_token |
| POST | `/x/passport-tv-login/h5/qrcode/confirm` | Login | H5 确认扫码（Cookie→TV） |
| POST | `/login/exit/v2` | Login | 登出；body: `biliCSRF` |
| GET | `/x/safecenter/user_login_devices` | AppSign+Login | 登录设备列表 |

---

## 登出

```
POST https://passport.bilibili.com/login/exit/v2
Content-Type: application/x-www-form-urlencoded

biliCSRF=<bili_jct>
```

随后清空本地 cookie / access_key。

---

## 登录后必做

1. 持久化 cookie jar + `access_key`
2. 调用 `GET /x/web-interface/nav` 拉用户信息 & 刷新 WBI key
3. （可选）`POST /x/internal/gaia-gateway/ExClimbWuzhi` 激活 buvid
4. （可选）`GET https://account.bilibili.com/site/getCoin` 硬币数

---

## 用户导航信息

```
GET https://api.bilibili.com/x/web-interface/nav
```

| 标记 | Cookie（登录后更完整） |
|------|------------------------|

`data` 关键字段：

| 字段 | 说明 |
|------|------|
| `isLogin` | 是否登录 |
| `mid` / `uname` / `face` | 用户 |
| `money` | 硬币 |
| `vipStatus` / `vipType` | 会员 |
| `wbi_img` | WBI 密钥 URL |
| `level_info` | 等级 |
| `official` | 认证 |

```
GET /x/web-interface/nav/stat # 关注/粉丝/动态数（当前用户）
```
