use thiserror::Error;

/// Domain-level semantic errors (Bilibili business + validation).
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum Error {
    #[error("invalid argument: {msg}")]
    InvalidArgument { msg: String },

    #[error("unauthenticated")]
    Unauthenticated,

    #[error("csrf validation failed")]
    Csrf,

    #[error("risk control: {message}")]
    RiskControl { message: String },

    #[error("not found")]
    NotFound,

    #[error("rate limited")]
    RateLimited,

    #[error("api error {code}: {message}")]
    Api { code: i32, message: String },
}

pub type Result<T> = std::result::Result<T, Error>;

/// Map Bilibili business `code` to domain [`Error`].
///
/// `code == 0` is success (`Ok(())`).
pub fn map_bili_code(code: i32, message: &str) -> Result<()> {
    match code {
        0 => Ok(()),
        -101 => Err(Error::Unauthenticated),
        -111 => Err(Error::Csrf),
        -404 => Err(Error::NotFound),
        -412 => Err(Error::RiskControl {
            message: message.to_string(),
        }),
        -509 => Err(Error::RateLimited),
        other => Err(Error::Api {
            code: other,
            message: message.to_string(),
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_success() {
        assert!(map_bili_code(0, "ok").is_ok());
    }

    #[test]
    fn maps_known_codes() {
        assert_eq!(map_bili_code(-101, ""), Err(Error::Unauthenticated));
        assert_eq!(map_bili_code(-111, ""), Err(Error::Csrf));
        assert_eq!(map_bili_code(-404, ""), Err(Error::NotFound));
        assert_eq!(map_bili_code(-509, ""), Err(Error::RateLimited));
        assert!(matches!(
            map_bili_code(-412, "风控"),
            Err(Error::RiskControl { message }) if message == "风控"
        ));
        assert!(matches!(
            map_bili_code(-400, "bad"),
            Err(Error::Api { code: -400, message }) if message == "bad"
        ));
    }
}
