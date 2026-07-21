//! Wire serde types for Bilibili playurl JSON.

use serde::Deserialize;

/// Bilibili often emits `"field": null` for empty lists; bare `Vec` + `default` only
/// covers *missing* keys, not null → "invalid type: null, expected a sequence".
pub(super) fn null_as_default<'de, D, T>(deserializer: D) -> std::result::Result<T, D::Error>
where
    D: serde::Deserializer<'de>,
    T: Default + Deserialize<'de>,
{
    Ok(Option::<T>::deserialize(deserializer)?.unwrap_or_default())
}

#[derive(Debug, Deserialize)]
pub(crate) struct PlayUrlData {
    #[serde(default)]
    pub(crate) quality: u32,
    #[serde(default)]
    pub(crate) timelength: i64,
    #[serde(default)]
    pub(crate) dash: Option<DashRaw>,
    #[serde(default, deserialize_with = "null_as_default")]
    pub(crate) durl: Vec<DurlRaw>,
    #[serde(default, deserialize_with = "null_as_default")]
    pub(crate) support_formats: Vec<SupportFormatRaw>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SupportFormatRaw {
    #[serde(default)]
    pub(crate) quality: u32,
    #[serde(default)]
    pub(crate) new_description: Option<String>,
    #[serde(default)]
    pub(crate) display_desc: Option<String>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct DashRaw {
    #[serde(default)]
    pub(crate) duration: Option<i64>,
    #[serde(default, deserialize_with = "null_as_default")]
    pub(crate) video: Vec<DashStreamRaw>,
    #[serde(default, deserialize_with = "null_as_default")]
    pub(crate) audio: Vec<DashStreamRaw>,
    #[serde(default)]
    pub(crate) dolby: Option<DashDolbyRaw>,
    #[serde(default)]
    pub(crate) flac: Option<DashFlacRaw>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct DashDolbyRaw {
    #[serde(default, deserialize_with = "null_as_default")]
    pub(crate) audio: Vec<DashStreamRaw>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct DashFlacRaw {
    /// Single FLAC / Hi-Res stream object (not a list).
    #[serde(default)]
    pub(crate) audio: Option<DashStreamRaw>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct DashStreamRaw {
    #[serde(default)]
    pub(crate) id: u32,
    #[serde(default, rename = "base_url")]
    pub(crate) base_url: Option<String>,
    #[serde(default, rename = "baseUrl")]
    pub(crate) base_url_camel: Option<String>,
    #[serde(default, rename = "backup_url")]
    pub(crate) backup_url: Option<Vec<String>>,
    #[serde(default, rename = "backupUrl")]
    pub(crate) backup_url_camel: Option<Vec<String>>,
    #[serde(default)]
    pub(crate) bandwidth: Option<u32>,
    #[serde(default)]
    pub(crate) codecs: Option<String>,
    #[serde(default)]
    pub(crate) width: Option<u32>,
    #[serde(default)]
    pub(crate) height: Option<u32>,
    #[serde(default, rename = "frameRate")]
    pub(crate) frame_rate: Option<String>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct DurlRaw {
    #[serde(default)]
    pub(crate) url: String,
    #[serde(default)]
    pub(crate) backup_url: Option<Vec<String>>,
}
