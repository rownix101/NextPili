//! Password encryption for passport login (RSA PKCS#1 v1.5).

use base64::{engine::general_purpose::STANDARD as B64, Engine};
use rand::rngs::OsRng;
use rsa::pkcs8::DecodePublicKey;
use rsa::{Pkcs1v15Encrypt, RsaPublicKey};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum PasswordCryptoError {
    #[error("invalid RSA public key: {0}")]
    InvalidKey(String),
    #[error("RSA encrypt failed: {0}")]
    Encrypt(String),
}

/// Encrypt `hash + password` with the PEM public key from `/web/key`.
///
/// Returns standard Base64 ciphertext expected by passport login APIs.
pub fn encrypt_password(public_key_pem: &str, hash: &str, password: &str) -> Result<String, PasswordCryptoError> {
    let pem = public_key_pem.trim();
    if pem.is_empty() {
        return Err(PasswordCryptoError::InvalidKey("empty PEM".into()));
    }
    let key = RsaPublicKey::from_public_key_pem(pem)
        .map_err(|e| PasswordCryptoError::InvalidKey(e.to_string()))?;
    let plain = format!("{hash}{password}");
    let mut rng = OsRng;
    let encrypted = key
        .encrypt(&mut rng, Pkcs1v15Encrypt, plain.as_bytes())
        .map_err(|e| PasswordCryptoError::Encrypt(e.to_string()))?;
    Ok(B64.encode(encrypted))
}

#[cfg(test)]
mod tests {
    use super::*;

    // Fixed PEM from bilibili-API-collect sample (1024-bit).
    const SAMPLE_PEM: &str = "-----BEGIN PUBLIC KEY-----\n\
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDjb4V7EidX/ym28t2ybo0U6t0n\n\
6p4ej8VjqKHg100va6jkNbNTrLQqMCQCAYtXMXXp2Fwkk6WR+12N9zknLjf+C9sx\n\
/+l48mjUU8RqahiFD1XT/u2e0m2EN029OhCgkHx3Fc/KlFSIbak93EH/XlYis0w+\n\
Xl69GV6klzgxW6d2xQIDAQAB\n\
-----END PUBLIC KEY-----\n";

    #[test]
    fn encrypts_hash_plus_password() {
        let out = encrypt_password(SAMPLE_PEM, "9333681c87fd8d6e", "password").unwrap();
        assert!(!out.is_empty());
        // PKCS1v15 is non-deterministic; only shape checks.
        let raw = B64.decode(&out).unwrap();
        assert_eq!(raw.len(), 128);
    }

    #[test]
    fn rejects_empty_pem() {
        assert!(encrypt_password("", "h", "p").is_err());
    }
}
