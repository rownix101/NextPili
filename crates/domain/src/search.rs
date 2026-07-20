use crate::id::DurationMs;
use serde::{Deserialize, Serialize};

/// Video hit from classification search (`search_type=video`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SearchVideoItem {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: DurationMs,
    pub play: i64,
}

/// Strip Bilibili search highlight markup (`<em class="keyword">…</em>`).
pub fn strip_search_highlight(title: &str) -> String {
    let mut out = String::with_capacity(title.len());
    let mut i = 0;
    let bytes = title.as_bytes();
    while i < bytes.len() {
        if bytes[i] == b'<' {
            if let Some(end) = title[i..].find('>') {
                i += end + 1;
                continue;
            }
        }
        // copy one UTF-8 char
        let ch = title[i..].chars().next().unwrap();
        out.push(ch);
        i += ch.len_utf8();
    }
    out
}

/// Parse search duration string (`MM:SS` / `H:MM:SS`) to milliseconds.
pub fn parse_duration_label(s: &str) -> DurationMs {
    let s = s.trim();
    if s.is_empty() {
        return DurationMs(0);
    }
    let parts: Vec<&str> = s.split(':').collect();
    let secs = match parts.as_slice() {
        [m, s] => {
            let m: i64 = m.parse().unwrap_or(0);
            let s: i64 = s.parse().unwrap_or(0);
            m.saturating_mul(60).saturating_add(s)
        }
        [h, m, s] => {
            let h: i64 = h.parse().unwrap_or(0);
            let m: i64 = m.parse().unwrap_or(0);
            let s: i64 = s.parse().unwrap_or(0);
            h.saturating_mul(3600)
                .saturating_add(m.saturating_mul(60))
                .saturating_add(s)
        }
        _ => s.parse::<i64>().unwrap_or(0),
    };
    DurationMs(secs.saturating_mul(1000).max(0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_em_tags() {
        assert_eq!(
            strip_search_highlight(r#"hello <em class="keyword">world</em>!"#),
            "hello world!"
        );
    }

    #[test]
    fn parses_duration() {
        assert_eq!(parse_duration_label("1:02").get(), 62_000);
        assert_eq!(parse_duration_label("1:02:03").get(), 3_723_000);
        assert_eq!(parse_duration_label("").get(), 0);
    }
}
