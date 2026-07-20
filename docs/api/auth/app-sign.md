# App 签名 (AppSign)

App 端 `appkey` + `sign` 签名。

上游说明：[bilibili-API-collect / app](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/APP.md)

用于 `app.bilibili.com`、passport 登录类接口，以及拦截器对 App 路径的统一签名。

## 常量（Android HD）

```text
appkey = "dfca71928277209b"
appsec = "b5475a8825547a4fc26c7d518eaaa02e"
```

其它常见 key（社区公开）：

| 端 | appkey | 说明 |
|----|--------|------|
| Android 手机 | `1d8b6e7d45233436` 等 | 多套轮换 |
| Android HD | `dfca71928277209b` | 默认（HD） |
| TV | `4409e2ce8ffd12b8` / sec `59b43e04ad6965f34319062b478f83dd` | 注释 |

## 算法

```text
1. params["appkey"] = appkey
2. params["ts"] = unix_seconds // 字符串或数字皆可；推荐字符串
3. 按 key 字典序排序全部参数
4. query = urlencode 拼接（与普通 form 一致）
5. sign = md5_hex( query + appsec )
6. params["sign"] = sign
```

注意：

- 计算 sign **之前** 若已有旧 `sign`，先删除再签。
- 登录态 App 请求额外带 `access_key`。
- 值需要 `Uri.encodeComponent`；空值写成 `key=` 或 `key` 需与实现保持一致（空 value 的编码方式需与签名侧保持一致；业务值通常非空）。

## 伪代码

```rust
fn app_sign(params: &mut BTreeMap<String, String>, appkey: &str, appsec: &str) {
 params.insert("appkey".into, appkey.into);
 params.insert(
 "ts".into,
 SystemTime::now
 .duration_since(UNIX_EPOCH).unwrap
 .as_secs
 .to_string,
 );
 params.remove("sign");

 let query = params
 .iter
 .map(|(k, v)| {
 if v.is_empty {
 urlencoding::encode(k).into_owned
 } else {
 format!("{}={}", urlencoding::encode(k), urlencoding::encode(v))
 }
 })
 .collect::<Vec<_>>
 .join("&");

 let sign = format!("{:x}", md5::compute(format!("{query}{appsec}")));
 params.insert("sign".into, sign);
}
```

## 拦截器行为

当请求 path 以 `https://app.bilibili.com` 开头：

1. 取 query map 或 POST body map
2. 若账号有 `access_key` → 写入
3. `AppSign.appSign(...)`
4. **不**附带 Web Cookie

## 典型需要 AppSign 的场景

| 场景 | 接口 |
|------|------|
| TV/HD 扫码登录 | `/x/passport-tv-login/qrcode/auth_code`、`.../poll` |
| 密码 / 短信登录 | `/x/passport-login/oauth2/login` 等 |
| App 推荐流 | `https://app.bilibili.com/x/v2/feed/index` |
| App 空间 | `/x/v2/space/*` |
| 直播 App 分区/列表 | `xlive/app-interface/*` |
| TV 播放地址 | `/x/tv/playurl` |
| 点赞/投币（App） | `/x/v2/view/like`、`/x/v2/view/coin/add` |

## access_key

来源：

1. App 密码/短信登录成功 → `data.token_info.access_token`
2. TV 扫码 poll 成功 → 同类 token 字段
3. Cookie 登录后可通过相关 oauth 接口兑换（部分流程用 `oauth2/access_token`）

用途：App 接口的登录凭证，等价于 Web 的 `SESSDATA`。

## 与 WBI 的区别

| | WBI | AppSign |
|--|-----|---------|
| 端 | Web | App / Passport |
| 密钥 | 每日 nav 动态 | 固定 appsec |
| 输出字段 | `w_rid`, `wts` | `sign`, `ts`, `appkey` |
| 登录态 | Cookie | `access_key` + 可选 Cookie |
