# WBI 签名

Web 端 WBI 签名：`w_rid` 与 `wts`。

上游说明：[bilibili-API-collect / wbi](https://github.com/SocialSisterYi/bilibili-API-collect/blob/master/docs/misc/sign/wbi.md)

Web 端部分接口要求 query 中带 `w_rid` 与 `wts`，否则返回 `-403` / 空数据。

## 流程

```text
1. 获取 img_key / sub_key
2. 拼接后按编码表重排 → mixin_key（32 字符）
3. 业务参数 + wts(当前秒级时间戳)
4. 参数按 key 字典序排列，做 URL encode，拼 query
5. w_rid = md5(query + mixin_key)
```

## 1. 获取密钥

`GET https://api.bilibili.com/x/web-interface/nav`（即 `Api.userInfo`）

响应（节选）：

```json
{
 "code": 0,
 "data": {
 "wbi_img": {
 "img_url": "https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png",
 "sub_url": "https://i0.hdslb.com/bfs/wbi/4932caff0ff746eab6f01bf08b70ac45.png"
 }
 }
}
```

```text
img_key = filename(img_url) // 去路径去扩展名 → 7cd084941338484aae1ad9425b84077c
sub_key = filename(sub_url) // 4932caff0ff746eab6f01bf08b70ac45
raw = img_key + sub_key // 64 字符
```

策略：**按自然日缓存** `mixin_key`；跨天或缺失时重新请求 nav。

## 2. mixin_key 重排表

对 `raw` 的字符按下表下标重排，再取前 32 字符：

```text
mixinKeyEncTab = [
 46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
]
```

实现只 map 前 32 个下标（表长 32），得到 32 字符 `mixin_key`：

```dart
// 等价逻辑
mixin_key = String.fromCharCodes(
 mixinKeyEncTab.map((i) => raw.codeUnits[i])
); // length == 32
```

## 3. 签名参数

```text
params["wts"] = now_unix_seconds
keys = sort(params.keys)
query = join( key=encode(value_filtered) for key in keys , "&" )
// value_filtered: 去掉 ! ' *
w_rid = md5_hex( query + mixin_key )
params["w_rid"] = w_rid
```

注意：

1. **先写 `wts`，再排序**；`w_rid` 本身不参与 MD5 原文。
2. value 先剔除字符 `!'*`，再 `Uri.encodeComponent`。
3. key 同样 `encodeComponent`。
4. 空值仍参与（`key=`）。

## 伪代码（Rust 风格）

```rust
fn enc_wbi(params: &mut BTreeMap<String, String>, mixin_key: &str) {
 let wts = SystemTime::now
 .duration_since(UNIX_EPOCH).unwrap
 .as_secs
 .to_string;
 params.insert("wts".into, wts);

 let query = params
 .iter
 .map(|(k, v)| {
 let v = v.replace(['!', '\'', '(', ')', '*'], "");
 format!("{}={}", urlencoding::encode(k), urlencoding::encode(&v))
 })
 .collect::<Vec<_>>
 .join("&");

 let digest = md5::compute(format!("{query}{mixin_key}"));
 params.insert("w_rid".into, format!("{digest:x}"));
}
```

## 需要 WBI 的典型接口

| 接口 | 说明 |
|------|------|
| `/x/web-interface/wbi/index/top/feed/rcmd` | Web 推荐 |
| `/x/player/wbi/playurl` | UGC 播放地址 |
| `/x/player/wbi/v2` | 播放页信息（字幕等） |
| `/x/web-interface/wbi/search/type` | 分类搜索 |
| `/x/web-interface/wbi/search/all/v2` | 综合搜索 |
| `/x/web-interface/wbi/search/default` | 默认搜索词 |
| `/x/space/wbi/acc/info` | 用户信息 |
| `/x/space/wbi/arc/search` | 用户投稿搜索 |
| `/x/web-interface/view/conclusion/get` | AI 总结 |
| `/x/web-interface/ranking/v2` | 排行榜 |
| 直播部分 GET | room play info / danmu token 等 |
| 若干动态/图文详情 | opus / article view |

> 路径含 `/wbi/` 的通常必须签；其它接口以联调是否返回 `-403` 为准。

## 测试建议

1. 拉 nav → 算出 mixin_key，与社区工具对照。
2. 对固定 `wts` 与参数集，断言 `w_rid` 稳定。
3. 请求 `playurl` / `search/type` 验证非 `-403`。
