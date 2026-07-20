//! Detect host GPU and derive [`domain::HwDecodeCaps`].

use domain::{GpuVendor, HwDecodeCaps};
use std::sync::OnceLock;

static CACHED: OnceLock<HwDecodeCaps> = OnceLock::new();

/// Cached probe (process lifetime). Safe to call from any thread.
pub fn hw_decode_caps() -> HwDecodeCaps {
    *CACHED.get_or_init(detect_hw_decode_caps)
}

fn detect_hw_decode_caps() -> HwDecodeCaps {
    #[cfg(target_os = "linux")]
    {
        if let Some(c) = probe_linux_drm() {
            tracing::info!(
                vendor = ?c.vendor,
                avc = c.avc,
                hevc = c.hevc,
                av1 = c.av1,
                "hw decode caps (linux drm)"
            );
            return c;
        }
    }
    #[cfg(target_os = "macos")]
    {
        let c = probe_macos();
        tracing::info!(
            vendor = ?c.vendor,
            avc = c.avc,
            hevc = c.hevc,
            av1 = c.av1,
            "hw decode caps (macos)"
        );
        return c;
    }
    #[cfg(target_os = "windows")]
    {
        if let Some(c) = probe_windows_best_effort() {
            tracing::info!(
                vendor = ?c.vendor,
                avc = c.avc,
                hevc = c.hevc,
                av1 = c.av1,
                "hw decode caps (windows)"
            );
            return c;
        }
    }
    let c = HwDecodeCaps::default();
    tracing::info!(
        vendor = ?c.vendor,
        avc = c.avc,
        hevc = c.hevc,
        av1 = c.av1,
        "hw decode caps (fallback default)"
    );
    c
}

#[cfg(target_os = "linux")]
fn probe_linux_drm() -> Option<HwDecodeCaps> {
    use std::fs;
    use std::path::PathBuf;

    let drm = PathBuf::from("/sys/class/drm");
    let entries = fs::read_dir(&drm).ok()?;
    let mut best: Option<(u16, u16, HwDecodeCaps)> = None;

    for ent in entries.flatten() {
        let name = ent.file_name();
        let name = name.to_string_lossy();
        // Prefer primary nodes: card0, card1, … skip card0-DP-1 connectors.
        if !name.starts_with("card") || name.contains('-') {
            continue;
        }
        let dev = ent.path().join("device");
        let vendor = read_hex_u16(&dev.join("vendor"))?;
        let device = read_hex_u16(&dev.join("device"))?;
        // Skip pure software / invalid.
        if vendor == 0 || device == 0 {
            continue;
        }
        let caps = HwDecodeCaps::from_pci(vendor, device);
        // Prefer discrete vendors over unknown; NVIDIA/AMD over Intel iGPU when both exist.
        let rank = match caps.vendor {
            GpuVendor::Nvidia => 3,
            GpuVendor::Amd => 3,
            GpuVendor::Intel => 1,
            _ => 0,
        };
        let replace = match best {
            None => true,
            Some((r, _, _)) => rank > r,
        };
        if replace {
            best = Some((rank, device, caps));
        }
    }
    best.map(|(_, _, c)| c)
}

#[cfg(target_os = "linux")]
fn read_hex_u16(path: &std::path::Path) -> Option<u16> {
    let s = std::fs::read_to_string(path).ok()?;
    let s = s.trim().trim_start_matches("0x").trim_start_matches("0X");
    u16::from_str_radix(s, 16).ok()
}

#[cfg(target_os = "macos")]
fn probe_macos() -> HwDecodeCaps {
    // Apple Silicon vs Intel Mac.
    if std::env::consts::ARCH == "aarch64" {
        HwDecodeCaps::apple_silicon()
    } else {
        HwDecodeCaps {
            vendor: GpuVendor::Apple,
            avc: true,
            hevc: true,
            av1: false,
        }
    }
}

#[cfg(target_os = "windows")]
fn probe_windows_best_effort() -> Option<HwDecodeCaps> {
    // Lightweight: look for vendor strings in common driver folders / env.
    // Full DXGI enum needs extra crates; keep heuristics only.
    use std::path::Path;
    if Path::new(r"C:\Windows\System32\nvapi64.dll").exists()
        || Path::new(r"C:\Windows\System32\nvcuda.dll").exists()
    {
        // Without device id, assume modern NV can do AV1 (Ampere+ majority of active desktops).
        return Some(HwDecodeCaps {
            vendor: GpuVendor::Nvidia,
            avc: true,
            hevc: true,
            av1: true,
        });
    }
    if Path::new(r"C:\Windows\System32\amdhip64.dll").exists()
        || Path::new(r"C:\Windows\System32\amdxc64.dll").exists()
    {
        // Unknown gen → no AV1 assumption (Polaris/Vega still common).
        return Some(HwDecodeCaps {
            vendor: GpuVendor::Amd,
            avc: true,
            hevc: true,
            av1: false,
        });
    }
    if Path::new(r"C:\Windows\System32\igcl64.dll").exists()
        || Path::new(r"C:\Windows\System32\ControlLib.dll").exists()
    {
        return Some(HwDecodeCaps {
            vendor: GpuVendor::Intel,
            avc: true,
            hevc: true,
            av1: false,
        });
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caps_are_stable() {
        let a = hw_decode_caps();
        let b = hw_decode_caps();
        assert_eq!(a, b);
    }
}
