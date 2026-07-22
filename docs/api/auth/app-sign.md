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
2. params["ts"] = unix_seconds // 字符串；推荐秒级
3. 删除旧 sign
4. 按 key 字典序排序
5. query = 对每个 key/value 做 RFC3986 component 编码后拼接
   - 非空：encode(key) + "=" + encode(value)
   - 空 value：仅 encode(key)（无 "="）——对齐 PiliPlus Uri.encodeComponent
6. sign = md5_hex( query + appsec )
7. params["sign"] = sign
```

注意：

- 计算 sign **之前** 若已有旧 `sign`，先删除再签。
- 登录态 App 请求额外带 `access_key`。
- **必须**对 value 做 percent-encode（`statistics` JSON 含 `{}"` 等）；未编码会导致「签名错误」。
- 编码字符集：unreserved = `A-Z a-z 0-9 - . _ ~`；其余 `%XX`（大写十六进制）。

## 伪代码

```rust
fn app_sign(params: &mut BTreeMap<String, String>, appkey: &str, appsec: &str) {
    params.remove("sign");
    params.insert("appkey".into(), appkey.into());
    params.insert("ts".into(), unix_secs().to_string());

    // sort by key (BTreeMap), percent-encode each component, then md5
    let query = params
        .iter()
        .map(|(k, v)| {
            if v.is_empty() {
                percent_encode(k)
            } else {
                format!("{}={}", percent_encode(k), percent_encode(v))
            }
        })
        .collect::<Vec<_>>()
        .join("&");

    let sign = md5_hex(format!("{query}{appsec}"));
    params.insert("sign".into(), sign);
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
