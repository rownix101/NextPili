//! Shared playurl URL / fps helpers.

pub(super) const WEB_REFERER: &str = "https://www.bilibili.com";
pub(super) const DEFAULT_UA: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 NextPili/0.1";

pub(super) fn first_url(
    base: &Option<String>,
    base_camel: &Option<String>,
    backup: &Option<Vec<String>>,
    backup_camel: &Option<Vec<String>>,
) -> String {
    base.as_ref()
        .filter(|s| !s.is_empty())
        .or(base_camel.as_ref().filter(|s| !s.is_empty()))
        .cloned()
        .or_else(|| {
            backup
                .as_ref()
                .and_then(|v| v.first())
                .filter(|s| !s.is_empty())
                .cloned()
        })
        .or_else(|| {
            backup_camel
                .as_ref()
                .and_then(|v| v.first())
                .filter(|s| !s.is_empty())
                .cloned()
        })
        .unwrap_or_default()
}

pub(super) fn merge_backups(a: &Option<Vec<String>>, b: &Option<Vec<String>>) -> Vec<String> {
    let mut out = a.clone().unwrap_or_default();
    if out.is_empty() {
        out = b.clone().unwrap_or_default();
    }
    out
}

pub(super) fn parse_fps(s: Option<&str>) -> Option<u32> {
    let s = s?;
    if s.is_empty() {
        return None;
    }
    if let Ok(f) = s.parse::<f64>() {
        return Some(f.round() as u32);
    }
    // "30000/1001"
    if let Some((n, d)) = s.split_once('/')
        && let (Ok(n), Ok(d)) = (n.parse::<f64>(), d.parse::<f64>())
        && d > 0.0
    {
        return Some((n / d).round() as u32);
    }
    None
}
