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

    pub fn is_empty(&self) -> bool {
        self.cookies.is_empty()
    }

    pub fn get(&self, name: &str) -> Option<&str> {
        self.cookies.get(name).map(String::as_str)
    }

    pub fn set(&mut self, name: impl Into<String>, value: impl Into<String>) {
        self.cookies.insert(name.into(), value.into());
    }

    pub fn remove(&mut self, name: &str) -> Option<String> {
        self.cookies.remove(name)
    }

    pub fn extend_from(&mut self, other: &CookieJar) {
        for (k, v) in &other.cookies {
            self.cookies.insert(k.clone(), v.clone());
        }
    }

    pub fn csrf(&self) -> Option<&str> {
        self.get("bili_jct")
    }

    pub fn sessdata(&self) -> Option<&str> {
        self.get("SESSDATA")
    }

    pub fn dede_user_id(&self) -> Option<&str> {
        self.get("DedeUserID")
    }

    /// Whether the jar looks like a logged-in session.
    pub fn has_login_session(&self) -> bool {
        self.sessdata().is_some_and(|s| !s.is_empty())
            && self.csrf().is_some_and(|s| !s.is_empty())
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

    /// Merge `Set-Cookie` name=value (first segment only) into the jar.
    pub fn apply_set_cookie(&mut self, set_cookie: &str) {
        let first = set_cookie.split(';').next().unwrap_or("").trim();
        if first.is_empty() {
            return;
        }
        if let Some((k, v)) = first.split_once('=') {
            let k = k.trim();
            if !k.is_empty() {
                self.set(k, v.trim());
            }
        }
    }

    /// Cookie request header value (stable key order for tests).
    pub fn header_value(&self) -> String {
        let mut pairs: Vec<_> = self.cookies.iter().collect();
        pairs.sort_by(|a, b| a.0.cmp(b.0));
        pairs
            .into_iter()
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
        let jar =
            CookieJar::parse_header("SESSDATA=abc; bili_jct=token123; Path=/; Domain=.bilibili.com");
        assert_eq!(jar.sessdata(), Some("abc"));
        assert_eq!(jar.csrf(), Some("token123"));
        assert!(jar.has_login_session());
    }

    #[test]
    fn apply_set_cookie() {
        let mut jar = CookieJar::new();
        jar.apply_set_cookie("buvid3=xyz; Path=/; Domain=.bilibili.com");
        assert_eq!(jar.get("buvid3"), Some("xyz"));
    }
}
