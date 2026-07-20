//! Danmaku segment protobuf (REST `seg.so` / gRPC DmSeg shape) → domain items.

use crate::error::{Error, Result};
use domain::DanmakuItem;

/// Approx. segment length used by Bilibili dm seg (6 minutes).
pub const DANMAKU_SEGMENT_MS: i64 = 6 * 60 * 1000;

/// Segment index (1-based) for a playback position.
pub fn segment_index_for_progress(progress_ms: i64) -> u32 {
    if progress_ms <= 0 {
        return 1;
    }
    let idx = progress_ms / DANMAKU_SEGMENT_MS + 1;
    idx.clamp(1, i64::from(u32::MAX)) as u32
}

/// Sort by progress; drop empty text.
pub fn normalize_danmaku(mut items: Vec<DanmakuItem>) -> Vec<DanmakuItem> {
    items.retain(|d| !d.text.trim().is_empty());
    items.sort_by_key(|d| d.progress_ms);
    items
}

/// Cap density: keep at most `max` items, preferring earlier progress then lower id.
pub fn limit_danmaku(items: Vec<DanmakuItem>, max: usize) -> Vec<DanmakuItem> {
    if max == 0 || items.len() <= max {
        return items;
    }
    let mut items = items;
    items.truncate(max);
    items
}

/// Parse REST `/x/v2/dm/web/seg.so` body (`DmSegMobileReply` protobuf wire).
pub fn parse_dm_seg_so(bytes: &[u8]) -> Result<Vec<DanmakuItem>> {
    if bytes.is_empty() {
        return Ok(Vec::new());
    }
    // Some error paths return JSON; reject early with a clear message.
    if bytes.first() == Some(&b'{') {
        return Err(Error::Invalid(
            "danmaku seg.so returned JSON (likely error envelope)".into(),
        ));
    }

    let mut items = Vec::new();
    let mut cursor = 0usize;
    while cursor < bytes.len() {
        let (tag, next) = read_varint(bytes, cursor)?;
        cursor = next;
        let field = (tag >> 3) as u32;
        let wire = (tag & 0x7) as u8;
        match (field, wire) {
            // elems: repeated DanmakuElem (length-delimited)
            (1, 2) => {
                let (len, next) = read_varint(bytes, cursor)?;
                cursor = next;
                let end = cursor
                    .checked_add(len as usize)
                    .ok_or_else(|| Error::Invalid("danmaku elem overflow".into()))?;
                if end > bytes.len() {
                    return Err(Error::Invalid("danmaku elem truncated".into()));
                }
                if let Some(item) = parse_danmaku_elem(&bytes[cursor..end])? {
                    items.push(item);
                }
                cursor = end;
            }
            _ => {
                cursor = skip_field(bytes, cursor, wire)?;
            }
        }
    }
    Ok(normalize_danmaku(items))
}

fn parse_danmaku_elem(bytes: &[u8]) -> Result<Option<DanmakuItem>> {
    let mut id: i64 = 0;
    let mut progress_ms: i64 = 0;
    let mut mode: i32 = 1;
    let mut fontsize: i32 = 25;
    let mut color: u32 = 0x00ff_ffff;
    let mut mid_hash = String::new();
    let mut text = String::new();

    let mut cursor = 0usize;
    while cursor < bytes.len() {
        let (tag, next) = read_varint(bytes, cursor)?;
        cursor = next;
        let field = (tag >> 3) as u32;
        let wire = (tag & 0x7) as u8;
        match (field, wire) {
            (1, 0) => {
                let (v, next) = read_varint(bytes, cursor)?;
                cursor = next;
                id = v as i64;
            }
            (2, 0) => {
                let (v, next) = read_varint(bytes, cursor)?;
                cursor = next;
                progress_ms = v as i64;
            }
            (3, 0) => {
                let (v, next) = read_varint(bytes, cursor)?;
                cursor = next;
                mode = v as i32;
            }
            (4, 0) => {
                let (v, next) = read_varint(bytes, cursor)?;
                cursor = next;
                fontsize = v as i32;
            }
            (5, 0) => {
                let (v, next) = read_varint(bytes, cursor)?;
                cursor = next;
                color = v as u32;
            }
            (6, 2) => {
                let (s, next) = read_string(bytes, cursor)?;
                cursor = next;
                mid_hash = s;
            }
            (7, 2) => {
                let (s, next) = read_string(bytes, cursor)?;
                cursor = next;
                text = s;
            }
            // idStr fallback when id is 0
            (12, 2) => {
                let (s, next) = read_string(bytes, cursor)?;
                cursor = next;
                if id == 0 {
                    if let Ok(parsed) = s.parse::<i64>() {
                        id = parsed;
                    }
                }
            }
            _ => {
                cursor = skip_field(bytes, cursor, wire)?;
            }
        }
    }

    if text.trim().is_empty() {
        return Ok(None);
    }
    Ok(Some(DanmakuItem {
        id,
        progress_ms,
        mode,
        fontsize,
        color,
        text,
        mid_hash,
    }))
}

fn read_varint(bytes: &[u8], mut i: usize) -> Result<(u64, usize)> {
    let mut result: u64 = 0;
    let mut shift = 0u32;
    loop {
        if i >= bytes.len() {
            return Err(Error::Invalid("varint truncated".into()));
        }
        let b = bytes[i];
        i += 1;
        result |= u64::from(b & 0x7f) << shift;
        if b & 0x80 == 0 {
            return Ok((result, i));
        }
        shift += 7;
        if shift > 63 {
            return Err(Error::Invalid("varint too long".into()));
        }
    }
}

fn read_string(bytes: &[u8], i: usize) -> Result<(String, usize)> {
    let (len, next) = read_varint(bytes, i)?;
    let end = next
        .checked_add(len as usize)
        .ok_or_else(|| Error::Invalid("string overflow".into()))?;
    if end > bytes.len() {
        return Err(Error::Invalid("string truncated".into()));
    }
    let s = String::from_utf8_lossy(&bytes[next..end]).into_owned();
    Ok((s, end))
}

fn skip_field(bytes: &[u8], i: usize, wire: u8) -> Result<usize> {
    match wire {
        0 => {
            let (_, next) = read_varint(bytes, i)?;
            Ok(next)
        }
        1 => {
            if i + 8 > bytes.len() {
                return Err(Error::Invalid("fixed64 truncated".into()));
            }
            Ok(i + 8)
        }
        2 => {
            let (len, next) = read_varint(bytes, i)?;
            let end = next
                .checked_add(len as usize)
                .ok_or_else(|| Error::Invalid("len field overflow".into()))?;
            if end > bytes.len() {
                return Err(Error::Invalid("len field truncated".into()));
            }
            Ok(end)
        }
        5 => {
            if i + 4 > bytes.len() {
                return Err(Error::Invalid("fixed32 truncated".into()));
            }
            Ok(i + 4)
        }
        _ => Err(Error::Invalid(format!("unsupported wire type {wire}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Encode a single DanmakuElem message (fields used by parser).
    fn encode_elem(
        id: i64,
        progress: i32,
        mode: i32,
        fontsize: i32,
        color: u32,
        mid_hash: &str,
        content: &str,
    ) -> Vec<u8> {
        let mut out = Vec::new();
        write_key(&mut out, 1, 0);
        write_varint(&mut out, id as u64);
        write_key(&mut out, 2, 0);
        write_varint(&mut out, progress as u64);
        write_key(&mut out, 3, 0);
        write_varint(&mut out, mode as u64);
        write_key(&mut out, 4, 0);
        write_varint(&mut out, fontsize as u64);
        write_key(&mut out, 5, 0);
        write_varint(&mut out, u64::from(color));
        write_key(&mut out, 6, 2);
        write_string(&mut out, mid_hash);
        write_key(&mut out, 7, 2);
        write_string(&mut out, content);
        out
    }

    fn write_key(out: &mut Vec<u8>, field: u32, wire: u8) {
        write_varint(out, u64::from((field << 3) | u32::from(wire)));
    }

    fn write_varint(out: &mut Vec<u8>, mut v: u64) {
        loop {
            let mut b = (v & 0x7f) as u8;
            v >>= 7;
            if v != 0 {
                b |= 0x80;
            }
            out.push(b);
            if v == 0 {
                break;
            }
        }
    }

    fn write_string(out: &mut Vec<u8>, s: &str) {
        write_varint(out, s.len() as u64);
        out.extend_from_slice(s.as_bytes());
    }

    fn wrap_seg(elems: &[Vec<u8>]) -> Vec<u8> {
        let mut out = Vec::new();
        for e in elems {
            write_key(&mut out, 1, 2);
            write_varint(&mut out, e.len() as u64);
            out.extend_from_slice(e);
        }
        out
    }

    #[test]
    fn parses_single_elem() {
        let elem = encode_elem(42, 1500, 1, 25, 0xffffff, "abc", "hello");
        let bytes = wrap_seg(&[elem]);
        let items = parse_dm_seg_so(&bytes).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, 42);
        assert_eq!(items[0].progress_ms, 1500);
        assert_eq!(items[0].text, "hello");
        assert_eq!(items[0].mid_hash, "abc");
        assert_eq!(items[0].color, 0xffffff);
    }

    #[test]
    fn sorts_and_drops_empty() {
        let a = encode_elem(1, 3000, 1, 25, 1, "a", "later");
        let b = encode_elem(2, 1000, 1, 25, 1, "b", "earlier");
        let c = encode_elem(3, 2000, 1, 25, 1, "c", "   ");
        let items = parse_dm_seg_so(&wrap_seg(&[a, b, c])).unwrap();
        assert_eq!(items.len(), 2);
        assert_eq!(items[0].text, "earlier");
        assert_eq!(items[1].text, "later");
    }

    #[test]
    fn segment_index() {
        assert_eq!(segment_index_for_progress(0), 1);
        assert_eq!(segment_index_for_progress(DANMAKU_SEGMENT_MS - 1), 1);
        assert_eq!(segment_index_for_progress(DANMAKU_SEGMENT_MS), 2);
    }

    #[test]
    fn limit_caps() {
        let items: Vec<_> = (0..10)
            .map(|i| DanmakuItem {
                id: i,
                progress_ms: i * 100,
                mode: 1,
                fontsize: 25,
                color: 0xffffff,
                text: format!("t{i}"),
                mid_hash: String::new(),
            })
            .collect();
        assert_eq!(limit_danmaku(items, 3).len(), 3);
    }
}
