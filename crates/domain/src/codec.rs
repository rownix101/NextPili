//! Video codec classification and hardware-decode preference (pure policy).

/// Normalized video codec family from DASH / live labels.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum VideoCodecKind {
    Av1,
    Hevc,
    Avc,
    Unknown,
}

/// GPU vendor used for capability heuristics.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub enum GpuVendor {
    Nvidia,
    Amd,
    Intel,
    Apple,
    #[default]
    Unknown,
}

/// Host decode capabilities used when picking a stream.
///
/// `true` means prefer this codec as **hardware-decodable**.
/// Soft-only codecs are still playable but ranked lower.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct HwDecodeCaps {
    pub vendor: GpuVendor,
    pub avc: bool,
    pub hevc: bool,
    pub av1: bool,
}

impl Default for HwDecodeCaps {
    /// Safe defaults: H.264 + H.265 HW assumed; AV1 not assumed.
    fn default() -> Self {
        Self {
            vendor: GpuVendor::Unknown,
            avc: true,
            hevc: true,
            av1: false,
        }
    }
}

impl HwDecodeCaps {
    /// Build from PCI vendor/device (Linux DRM / Windows PCI).
    ///
    /// Heuristics are intentionally conservative for AV1.
    pub fn from_pci(vendor_id: u16, device_id: u16) -> Self {
        match vendor_id {
            0x10de => Self::nvidia(device_id),
            0x1002 | 0x1022 => Self::amd(device_id),
            0x8086 => Self::intel(device_id),
            _ => Self::default(),
        }
    }

    fn nvidia(device_id: u16) -> Self {
        // AV1 decode: Ampere+ (GA10x …); device IDs typically ≥ 0x2200.
        Self {
            vendor: GpuVendor::Nvidia,
            avc: true,
            hevc: true,
            av1: device_id >= 0x2200,
        }
    }

    fn amd(device_id: u16) -> Self {
        // AV1 decode: RDNA2+ (Navi21+ …). Navi10/14 (RX 5000) and Polaris have no AV1.
        // Navi21 starts ~0x73a0; Polaris RX 580 is 0x6fdf.
        Self {
            vendor: GpuVendor::Amd,
            avc: true,
            hevc: true,
            av1: device_id >= 0x73a0,
        }
    }

    fn intel(device_id: u16) -> Self {
        // AV1: Tiger Lake / Xe / Arc-ish ranges (conservative allow-list + floor).
        let av1 = matches!(
            device_id,
            0x9a00..=0x9aff // Tiger Lake
                | 0x4600..=0x46ff // Alder / Rocket area
                | 0x4c00..=0x4cff
                | 0x5600..=0x56ff // DG2 Arc
                | 0xa700..=0xa7ff // Raptor / Meteor-ish
                | 0x7d00..=0x7dff
        ) || device_id >= 0x9a40;
        Self {
            vendor: GpuVendor::Intel,
            avc: true,
            hevc: true,
            av1,
        }
    }

    pub fn apple_silicon() -> Self {
        // VT: AVC/HEVC widely; AV1 HW on newer chips — enable AV1 preference on aarch64.
        Self {
            vendor: GpuVendor::Apple,
            avc: true,
            hevc: true,
            av1: true,
        }
    }

    pub fn supports(&self, kind: VideoCodecKind) -> bool {
        match kind {
            VideoCodecKind::Av1 => self.av1,
            VideoCodecKind::Hevc => self.hevc,
            VideoCodecKind::Avc => self.avc,
            VideoCodecKind::Unknown => false,
        }
    }
}

/// Map Bilibili `codecs` / live `codec_name` → kind.
pub fn classify_video_codec(codec: &str) -> VideoCodecKind {
    let c = codec.trim().to_ascii_lowercase();
    if c.is_empty() {
        return VideoCodecKind::Unknown;
    }
    if c.starts_with("av01") || c.starts_with("av1") || c == "av01" {
        return VideoCodecKind::Av1;
    }
    if c.starts_with("hev")
        || c.starts_with("hvc")
        || c.starts_with("h265")
        || c.contains("hevc")
    {
        return VideoCodecKind::Hevc;
    }
    if c.starts_with("avc") || c.starts_with("h264") || c.starts_with("avc1") {
        return VideoCodecKind::Avc;
    }
    // Live API short names.
    match c.as_str() {
        "av1" => VideoCodecKind::Av1,
        "hevc" | "h265" => VideoCodecKind::Hevc,
        "avc" | "h264" => VideoCodecKind::Avc,
        _ => VideoCodecKind::Unknown,
    }
}

/// Prefer **hard-decodable** codecs; among them **AV1 > HEVC > AVC**.
/// Soft-only codecs rank below any HW-capable option.
pub fn video_codec_score(kind: VideoCodecKind, caps: HwDecodeCaps) -> i32 {
    let efficiency = match kind {
        VideoCodecKind::Av1 => 3,
        VideoCodecKind::Hevc => 2,
        VideoCodecKind::Avc => 1,
        VideoCodecKind::Unknown => 0,
    };
    if caps.supports(kind) {
        100 + efficiency
    } else {
        efficiency
    }
}

/// Pick best stream id at a fixed qn using codec score (higher bandwidth as tie-break).
pub fn pick_best_codec_stream<'a, S, FCodec, FBw, FId>(
    same_qn: &'a [S],
    caps: HwDecodeCaps,
    codec_of: FCodec,
    bandwidth_of: FBw,
    id_of: FId,
) -> Option<&'a S>
where
    FCodec: Fn(&S) -> &str,
    FBw: Fn(&S) -> u32,
    FId: Fn(&S) -> &str,
{
    same_qn.iter().max_by(|a, b| {
        let sa = video_codec_score(classify_video_codec(codec_of(a)), caps);
        let sb = video_codec_score(classify_video_codec(codec_of(b)), caps);
        sa.cmp(&sb)
            .then_with(|| bandwidth_of(a).cmp(&bandwidth_of(b)))
            .then_with(|| id_of(a).cmp(id_of(b)))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_dash_labels() {
        assert_eq!(classify_video_codec("avc1.640032"), VideoCodecKind::Avc);
        assert_eq!(classify_video_codec("hev1.1.6.L150.90"), VideoCodecKind::Hevc);
        assert_eq!(classify_video_codec("av01.0.08M.08"), VideoCodecKind::Av1);
        assert_eq!(classify_video_codec("avc"), VideoCodecKind::Avc);
    }

    #[test]
    fn rx580_prefers_hevc_over_av1() {
        // Polaris RX 580 2048SP
        let caps = HwDecodeCaps::from_pci(0x1002, 0x6fdf);
        assert_eq!(caps.vendor, GpuVendor::Amd);
        assert!(caps.hevc && caps.avc);
        assert!(!caps.av1);
        assert!(
            video_codec_score(VideoCodecKind::Hevc, caps)
                > video_codec_score(VideoCodecKind::Av1, caps)
        );
        assert!(
            video_codec_score(VideoCodecKind::Hevc, caps)
                > video_codec_score(VideoCodecKind::Avc, caps)
        );
    }

    #[test]
    fn ampere_prefers_av1() {
        let caps = HwDecodeCaps::from_pci(0x10de, 0x2204); // RTX 3090-ish
        assert!(caps.av1);
        assert!(
            video_codec_score(VideoCodecKind::Av1, caps)
                > video_codec_score(VideoCodecKind::Hevc, caps)
        );
    }

    #[test]
    fn rdna2_av1() {
        let caps = HwDecodeCaps::from_pci(0x1002, 0x73bf); // 6800 XT-ish
        assert!(caps.av1);
    }
}
