use serde::{Deserialize, Serialize};

/// Account routing slots (multi-account isolation).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum AccountSlot {
    /// Default write ops and profile.
    Main,
    /// History / heartbeat reporting isolation.
    Heartbeat,
    /// Home recommend / popular / search isolation.
    Recommend,
    /// Playurl isolation.
    Video,
}

impl AccountSlot {
    pub const ALL: [AccountSlot; 4] = [
        AccountSlot::Main,
        AccountSlot::Heartbeat,
        AccountSlot::Recommend,
        AccountSlot::Video,
    ];
}
