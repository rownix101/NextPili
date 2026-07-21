//! Quality / audio display labels for playurl streams.

/// qn → short display label.
pub fn quality_label(qn: u32) -> String {
    match qn {
        16 => "360P".into(),
        32 => "480P".into(),
        64 => "720P".into(),
        74 => "720P60".into(),
        80 => "1080P".into(),
        112 => "1080P+".into(),
        116 => "1080P60".into(),
        120 => "4K".into(),
        125 => "HDR".into(),
        126 => "杜比视界".into(),
        127 => "8K".into(),
        other => format!("qn{other}"),
    }
}

/// Preferred default standard audio qn (192K).
pub const AUDIO_QN_192K: u32 = 30280;

/// Audio role stored in [`Stream::role`].
pub const AUDIO_ROLE_STANDARD: &str = "standard";
pub const AUDIO_ROLE_DOLBY: &str = "dolby";
pub const AUDIO_ROLE_HIRES: &str = "hires";

/// Classify DASH audio id → role.
pub fn audio_role(id: u32) -> &'static str {
    match id {
        // Dolby Atmos / Dolby audio
        30250 | 30252 | 30255 => AUDIO_ROLE_DOLBY,
        // Hi-Res lossless
        30251 => AUDIO_ROLE_HIRES,
        _ => AUDIO_ROLE_STANDARD,
    }
}

/// DASH audio id → short menu label.
///
/// Standard ladder: 64K / 132K / 192K. Dolby & Hi-Res are independent options.
pub fn audio_label(id: u32, bandwidth: u32) -> String {
    match id {
        30216 => "64K".into(),
        30232 => "132K".into(),
        30280 => "192K".into(),
        30250 | 30252 | 30255 => "杜比全景声".into(),
        30251 => "Hi-Res".into(),
        // Unknown standard: show bitrate estimate.
        other if audio_role(other) == AUDIO_ROLE_STANDARD && bandwidth >= 1000 => {
            format!("{}K", bandwidth / 1000)
        }
        other => format!("audio-{other}"),
    }
}

/// Rank for default / menu sort (higher = preferred among standard).
/// Dolby / Hi-Res are not in the default ladder.
pub(super) fn audio_standard_rank(id: u32, bandwidth: u32) -> u32 {
    match id {
        30280 => 192_000,
        30232 => 132_000,
        30216 => 64_000,
        _ => bandwidth.max(1),
    }
}
