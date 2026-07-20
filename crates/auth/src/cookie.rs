use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Simple cookie jar suitable for serialization into store.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CookieJar {
    /// name -> value
    pub cookies: HashMap<String, String>,
}

impl CookieJar {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn get(&self, name: &str) -> Option<&str> {
        self.cookies.get(name).map(String::as_str)
    }

    pub fn set(&mut self, name: impl Into<String>, value: impl Into<String>) {
        self.cookies.insert(name.into(), value.into());
    }

    pub fn csrf(&self) -> Option<&str> {
        self.get("bili_jct")
    }

    pub fn sessdata(&self) -> Option<&str> {
        self.get("SESSDATA")
    }

    /// Parse `k=v; k2=v2` style cookie header / browser export line.
    pub fn parse_header(raw: &str) -> Self {
        let mut jar = Self::new();
        for part in raw.split(';') {
            let part = part.trim();
            if part.is_empty() {
                continue;
            }
            // Skip attributes like Path=, Domain=, Secure
            let lower = part.to_ascii_lowercase();
            if lower.starts_with("path=")
                || lower.starts_with("domain=")
                || lower.starts_with("expires=")
                || lower.starts_with("max-age=")
                || lower == "secure"
                || lower == "httponly"
                || lower.starts_with("samesite=")
            {
                continue;
            }
            if let Some((k, v)) = part.split_once('=') {
                let k = k.trim();
                let v = v.trim();
                if !k.is_empty() {
                    jar.set(k, v);
                }
            }
        }
        jar
    }

    /// Cookie request header value.
    pub fn header_value(&self) -> String {
        self.cookies
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join("; ")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_and_csrf() {
        let jar = CookieJar::parse_header("SESSDATA=abc; bili_jct=token123; Path=/; Domain=.bilibili.com");
        assert_eq!(jar.sessdata(), Some("abc"));
        assert_eq!(jar.csrf(), Some("token123"));
    }
}
