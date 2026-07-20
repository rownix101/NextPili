use crate::error::{Error, Result};
use crate::middleware::{
    apply_app_sign, compose_cookie_header, inject_csrf, web_baseline_headers, AuthMode, SignMode,
};
use crate::response::{parse_bili_json, BiliResponse};
use auth::{constants, Account, AppSigner, CookieJar, UA_ANDROID_HD, UA_WEB, WbiSigner};
use reqwest::header::{HeaderMap, HeaderName, HeaderValue, CONTENT_TYPE, COOKIE, REFERER, USER_AGENT};
use reqwest::{Client, Method};
use serde::de::DeserializeOwned;
use std::collections::BTreeMap;
use std::time::Duration;

#[derive(Debug, Clone)]
pub struct ClientConfig {
    pub user_agent: String,
    pub proxy: Option<String>,
    pub timeout: Duration,
}

impl Default for ClientConfig {
    fn default() -> Self {
        Self {
            user_agent: UA_WEB.into(),
            proxy: None,
            timeout: Duration::from_secs(20),
        }
    }
}

/// Shared Bilibili HTTP client.
///
/// Multi-account: Cookie is injected per-request from the Account jar (no shared cookie jar).
#[derive(Clone)]
pub struct BiliClient {
    inner: Client,
    config: ClientConfig,
    app_signer: AppSigner,
}

impl BiliClient {
    pub fn new(config: ClientConfig) -> Result<Self> {
        let mut builder = Client::builder()
            .user_agent(config.user_agent.clone())
            .timeout(config.timeout)
            // Explicit Cookie header per account — do not use a global store.
            .cookie_store(false)
            .redirect(reqwest::redirect::Policy::limited(10));

        if let Some(proxy) = &config.proxy {
            let proxy = reqwest::Proxy::all(proxy).map_err(|e| Error::Network(e.to_string()))?;
            builder = builder.proxy(proxy);
        }

        let inner = builder
            .build()
            .map_err(|e| Error::Network(e.to_string()))?;

        Ok(Self {
            inner,
            config,
            app_signer: AppSigner::android_hd(),
        })
    }

    pub fn raw(&self) -> &Client {
        &self.inner
    }

    pub fn config(&self) -> &ClientConfig {
        &self.config
    }

    pub fn app_signer(&self) -> &AppSigner {
        &self.app_signer
    }

    /// Resolve relative path against a host base.
    pub fn resolve_url(base: &str, path_or_url: &str) -> String {
        if path_or_url.starts_with("http://") || path_or_url.starts_with("https://") {
            path_or_url.to_string()
        } else if path_or_url.starts_with('/') {
            format!("{base}{path_or_url}")
        } else {
            format!("{base}/{path_or_url}")
        }
    }

    pub async fn get_text(&self, url: &str) -> Result<String> {
        let resp = self
            .inner
            .get(url)
            .send()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;
        resp.text()
            .await
            .map_err(|e| Error::Network(e.to_string()))
    }

    /// Execute a signed/authenticated form POST and parse BiliResponse.
    pub async fn post_form_bili<T: DeserializeOwned>(
        &self,
        url: &str,
        mut params: BTreeMap<String, String>,
        opts: RequestOptions<'_>,
    ) -> Result<BiliResponse<T>> {
        self.apply_auth_params(&mut params, &opts)?;
        let body = form_encode(&params);
        let mut headers = self.build_headers(&opts, true)?;
        headers.insert(
            CONTENT_TYPE,
            HeaderValue::from_static("application/x-www-form-urlencoded"),
        );

        let resp = self
            .inner
            .request(Method::POST, url)
            .headers(headers)
            .body(body)
            .send()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;

        let text = resp
            .text()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;
        parse_bili_json(&text)
    }

    /// Form POST returning raw body + response headers (for Set-Cookie login).
    pub async fn post_form_raw(
        &self,
        url: &str,
        mut params: BTreeMap<String, String>,
        opts: RequestOptions<'_>,
    ) -> Result<(String, HeaderMap)> {
        self.apply_auth_params(&mut params, &opts)?;
        let body = form_encode(&params);
        let mut headers = self.build_headers(&opts, true)?;
        headers.insert(
            CONTENT_TYPE,
            HeaderValue::from_static("application/x-www-form-urlencoded"),
        );

        let resp = self
            .inner
            .request(Method::POST, url)
            .headers(headers)
            .body(body)
            .send()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;

        let resp_headers = resp.headers().clone();
        let text = resp
            .text()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;
        Ok((text, resp_headers))
    }

    /// Execute GET with query params and parse BiliResponse.
    pub async fn get_bili<T: DeserializeOwned>(
        &self,
        url: &str,
        mut params: BTreeMap<String, String>,
        opts: RequestOptions<'_>,
    ) -> Result<BiliResponse<T>> {
        self.apply_auth_params(&mut params, &opts)?;
        let headers = self.build_headers(&opts, false)?;
        let resp = self
            .inner
            .request(Method::GET, url)
            .headers(headers)
            .query(&params.into_iter().collect::<Vec<_>>())
            .send()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;
        let text = resp
            .text()
            .await
            .map_err(|e| Error::Network(e.to_string()))?;
        parse_bili_json(&text)
    }

    fn apply_auth_params(
        &self,
        params: &mut BTreeMap<String, String>,
        opts: &RequestOptions<'_>,
    ) -> Result<()> {
        if opts.csrf {
            let jar = opts
                .account
                .map(|a| &a.cookie_jar)
                .ok_or_else(|| Error::Auth("csrf requires account cookie".into()))?;
            inject_csrf(params, jar).map_err(Error::Auth)?;
        }

        match opts.sign {
            SignMode::None => {}
            SignMode::AppSign => {
                let ak = opts.account.and_then(|a| a.access_key.as_deref());
                apply_app_sign(params, &self.app_signer, ak);
            }
            SignMode::Wbi => {
                let signer = opts
                    .wbi
                    .ok_or_else(|| Error::Auth("wbi signer required".into()))?;
                // Use mutable path via re-sign helper on a clone of keys.
                let mut tmp = signer.clone();
                let wts = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_secs() as i64)
                    .unwrap_or(0);
                tmp.sign_with_keys(params, wts)
                    .map_err(|e| Error::Auth(e.into()))?;
            }
        }
        Ok(())
    }

    fn build_headers(&self, opts: &RequestOptions<'_>, app_ua: bool) -> Result<HeaderMap> {
        let mut headers = HeaderMap::new();
        let ua = if matches!(opts.sign, SignMode::AppSign) || app_ua && opts.prefer_app_ua {
            UA_ANDROID_HD
        } else {
            self.config.user_agent.as_str()
        };
        headers.insert(
            USER_AGENT,
            HeaderValue::from_str(ua).map_err(|e| Error::Network(e.to_string()))?,
        );

        let attach_cookie = matches!(opts.auth, AuthMode::Cookie | AuthMode::OptionalLogin)
            || (opts.auth == AuthMode::None && opts.device_buvid3.is_some());

        if attach_cookie && opts.auth != AuthMode::App {
            if let Some(cookie) = compose_cookie_header(opts.account, opts.device_buvid3) {
                headers.insert(
                    COOKIE,
                    HeaderValue::from_str(&cookie).map_err(|e| Error::Network(e.to_string()))?,
                );
            } else if opts.auth == AuthMode::Cookie {
                return Err(Error::Auth("cookie auth required but jar empty".into()));
            }
        }

        if !matches!(opts.sign, SignMode::AppSign) {
            let mid = opts.account.map(|a| a.mid.get());
            for (k, v) in web_baseline_headers(mid) {
                if let (Ok(name), Ok(val)) = (
                    HeaderName::from_bytes(k.as_bytes()),
                    HeaderValue::from_str(&v),
                ) {
                    headers.insert(name, val);
                }
            }
        } else {
            headers.insert(REFERER, HeaderValue::from_static(constants::WWW_BASE));
        }

        Ok(headers)
    }
}

/// Per-request auth/sign options.
#[derive(Debug, Clone, Copy)]
pub struct RequestOptions<'a> {
    pub account: Option<&'a Account>,
    pub device_buvid3: Option<&'a str>,
    pub auth: AuthMode,
    pub sign: SignMode,
    pub csrf: bool,
    pub wbi: Option<&'a WbiSigner>,
    pub prefer_app_ua: bool,
}

impl Default for RequestOptions<'_> {
    fn default() -> Self {
        Self {
            account: None,
            device_buvid3: None,
            auth: AuthMode::None,
            sign: SignMode::None,
            csrf: false,
            wbi: None,
            prefer_app_ua: false,
        }
    }
}

impl<'a> RequestOptions<'a> {
    pub fn app_sign() -> Self {
        Self {
            auth: AuthMode::App,
            sign: SignMode::AppSign,
            prefer_app_ua: true,
            ..Self::default()
        }
    }

    pub fn web_cookie(account: &'a Account, buvid3: Option<&'a str>) -> Self {
        Self {
            account: Some(account),
            device_buvid3: buvid3,
            auth: AuthMode::Cookie,
            sign: SignMode::None,
            prefer_app_ua: false,
            ..Self::default()
        }
    }

    pub fn with_device_buvid(mut self, buvid3: Option<&'a str>) -> Self {
        self.device_buvid3 = buvid3;
        self
    }

    pub fn with_account(mut self, account: Option<&'a Account>) -> Self {
        self.account = account;
        self
    }

    pub fn with_wbi(mut self, wbi: &'a WbiSigner) -> Self {
        self.wbi = Some(wbi);
        self.sign = SignMode::Wbi;
        self
    }
}

fn form_encode(params: &BTreeMap<String, String>) -> String {
    params
        .iter()
        .map(|(k, v)| {
            format!(
                "{}={}",
                urlencoding_minimal(k),
                urlencoding_minimal(v)
            )
        })
        .collect::<Vec<_>>()
        .join("&")
}

/// Minimal form encoding (space as %20; encode reserved).
fn urlencoding_minimal(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

/// Merge Set-Cookie headers into a jar.
pub fn merge_set_cookies(jar: &mut CookieJar, headers: &HeaderMap) {
    for val in headers.get_all(reqwest::header::SET_COOKIE) {
        if let Ok(s) = val.to_str() {
            jar.apply_set_cookie(s);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolve_relative() {
        assert_eq!(
            BiliClient::resolve_url(constants::API_BASE, "/x/web-interface/nav"),
            "https://api.bilibili.com/x/web-interface/nav"
        );
        assert_eq!(
            BiliClient::resolve_url(constants::API_BASE, "https://passport.bilibili.com/x"),
            "https://passport.bilibili.com/x"
        );
    }
}
