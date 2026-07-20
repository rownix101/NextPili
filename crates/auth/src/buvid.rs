use md5::{Digest, Md5};
use uuid::Uuid;

/// Generate a `buvid3`-like device id.
///
/// Format is implementation-defined; shape validated for non-empty printable token.
pub fn generate_buvid3() -> String {
    let uuid = Uuid::new_v4().to_string().replace('-', "").to_uppercase();
    let mut hasher = Md5::new();
    hasher.update(uuid.as_bytes());
    let digest = hasher.finalize();
    let hex = hex::encode(digest).to_uppercase();
    // Common pattern: XX...XXXinfoc
    format!("{hex}infoc")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buvid_format() {
        let b = generate_buvid3();
        assert!(b.ends_with("infoc"));
        assert!(b.len() > 10);
    }
}
