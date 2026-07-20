use crate::error::{Error, Result};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;
use uuid::Uuid;

/// Local account primary key.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AccountId(pub String);

impl AccountId {
    pub fn new() -> Self {
        Self(Uuid::new_v4().to_string())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl Default for AccountId {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Display for AccountId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// Bilibili user mid. `0` may be used as unauthenticated placeholder.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct UserMid(pub i64);

impl UserMid {
    pub fn new(mid: i64) -> Result<Self> {
        if mid < 0 {
            return Err(Error::InvalidArgument {
                msg: format!("UserMid must be >= 0, got {mid}"),
            });
        }
        Ok(Self(mid))
    }

    pub fn get(self) -> i64 {
        self.0
    }

    pub fn is_logged_in(self) -> bool {
        self.0 > 0
    }
}

/// Video content id (cid). Must be > 0.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Cid(pub i64);

impl Cid {
    pub fn new(cid: i64) -> Result<Self> {
        if cid <= 0 {
            return Err(Error::InvalidArgument {
                msg: format!("Cid must be > 0, got {cid}"),
            });
        }
        Ok(Self(cid))
    }

    pub fn get(self) -> i64 {
        self.0
    }
}

/// Bilibili quality number (qn).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct QualityQn(pub u32);

impl QualityQn {
    pub fn get(self) -> u32 {
        self.0
    }
}

/// Duration in milliseconds.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct DurationMs(pub i64);

impl DurationMs {
    pub fn get(self) -> i64 {
        self.0
    }
}

/// Video id: BV string or AV number.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum VideoId {
    Bvid(String),
    Aid(i64),
}

impl VideoId {
    pub fn parse(input: &str) -> Result<Self> {
        let s = input.trim();
        if s.is_empty() {
            return Err(Error::InvalidArgument {
                msg: "empty video id".into(),
            });
        }

        if let Some(rest) = s
            .strip_prefix("av")
            .or_else(|| s.strip_prefix("AV"))
            .or_else(|| s.strip_prefix("Av"))
        {
            let aid: i64 = rest.parse().map_err(|_| Error::InvalidArgument {
                msg: format!("invalid aid: {s}"),
            })?;
            if aid <= 0 {
                return Err(Error::InvalidArgument {
                    msg: format!("aid must be > 0, got {aid}"),
                });
            }
            return Ok(Self::Aid(aid));
        }

        if s.len() >= 3 && s.as_bytes()[..2].eq_ignore_ascii_case(b"BV") {
            return Ok(Self::Bvid(s.to_string()));
        }

        if s.chars().all(|c| c.is_ascii_digit()) {
            let aid: i64 = s.parse().map_err(|_| Error::InvalidArgument {
                msg: format!("invalid aid: {s}"),
            })?;
            if aid <= 0 {
                return Err(Error::InvalidArgument {
                    msg: format!("aid must be > 0, got {aid}"),
                });
            }
            return Ok(Self::Aid(aid));
        }

        Err(Error::InvalidArgument {
            msg: format!("unrecognized video id: {s}"),
        })
    }
}

impl FromStr for VideoId {
    type Err = Error;

    fn from_str(s: &str) -> Result<Self> {
        Self::parse(s)
    }
}

impl fmt::Display for VideoId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Bvid(b) => f.write_str(b),
            Self::Aid(a) => write!(f, "av{a}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_bvid() {
        assert_eq!(
            VideoId::parse("BV1xx411c7mD").unwrap(),
            VideoId::Bvid("BV1xx411c7mD".into())
        );
    }

    #[test]
    fn parse_aid_forms() {
        assert_eq!(VideoId::parse("170001").unwrap(), VideoId::Aid(170001));
        assert_eq!(VideoId::parse("av170001").unwrap(), VideoId::Aid(170001));
        assert_eq!(VideoId::parse("AV170001").unwrap(), VideoId::Aid(170001));
    }

    #[test]
    fn reject_invalid() {
        assert!(VideoId::parse("").is_err());
        assert!(VideoId::parse("not-a-video").is_err());
        assert!(VideoId::parse("av0").is_err());
        assert!(Cid::new(0).is_err());
        assert!(UserMid::new(-1).is_err());
    }
}
