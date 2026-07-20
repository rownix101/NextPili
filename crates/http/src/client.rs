use crate::error::{Error, Result};
use reqwest::Client;
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
            user_agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 NextPili/0.1".into(),
            proxy: None,
            timeout: Duration::from_secs(20),
        }
    }
}

/// Shared Bilibili HTTP client.
///
/// Endpoint modules and signing middleware land in P1+.
#[derive(Clone)]
pub struct BiliClient {
    inner: Client,
    config: ClientConfig,
}

impl BiliClient {
    pub fn new(config: ClientConfig) -> Result<Self> {
        let mut builder = Client::builder()
            .user_agent(config.user_agent.clone())
            .timeout(config.timeout)
            .cookie_store(true)
            .redirect(reqwest::redirect::Policy::limited(10));

        if let Some(proxy) = &config.proxy {
            let proxy = reqwest::Proxy::all(proxy).map_err(|e| Error::Network(e.to_string()))?;
            builder = builder.proxy(proxy);
        }

        let inner = builder
            .build()
            .map_err(|e| Error::Network(e.to_string()))?;

        Ok(Self { inner, config })
    }

    pub fn raw(&self) -> &Client {
        &self.inner
    }

    pub fn config(&self) -> &ClientConfig {
        &self.config
    }

    /// Lightweight connectivity check (no Bilibili business semantics).
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
}
