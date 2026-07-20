use domain::DanmakuItem;

/// Normalize / sort danmaku by progress (placeholder for denser logic later).
pub fn normalize_danmaku(mut items: Vec<DanmakuItem>) -> Vec<DanmakuItem> {
    items.sort_by_key(|d| d.progress_ms);
    items
}
