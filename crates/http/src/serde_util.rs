//! Shared Serde helpers for Bilibili JSON quirks.

use serde::{Deserialize, Deserializer};

/// Treat JSON `null` as `T::default()` (needed for bare `Vec` fields).
///
/// `#[serde(default)]` only applies when the key is *missing*; Bilibili often
/// returns `"list": null` which still fails for `Vec` without this.
pub fn null_as_default<'de, D, T>(deserializer: D) -> Result<T, D::Error>
where
    D: Deserializer<'de>,
    T: Default + Deserialize<'de>,
{
    Ok(Option::<T>::deserialize(deserializer)?.unwrap_or_default())
}
