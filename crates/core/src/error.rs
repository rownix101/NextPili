use serde::{Deserialize, Serialize};

/// FFI-facing error kind.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ErrorKind {
    Unauthenticated,
    Csrf,
    RiskControl,
    NotFound,
    RateLimited,
    InvalidArgument,
    Network,
    Parse,
    Storage,
    Internal,
}

/// Error returned across the FFI boundary.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppError {
    pub kind: ErrorKind,
    pub message: String,
    pub bili_code: Option<i32>,
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}: {}", self.kind, self.message)
    }
}

impl std::error::Error for AppError {}

impl AppError {
    pub fn new(kind: ErrorKind, message: impl Into<String>) -> Self {
        Self {
            kind,
            message: message.into(),
            bili_code: None,
        }
    }

    pub fn with_bili_code(mut self, code: i32) -> Self {
        self.bili_code = Some(code);
        self
    }

    pub fn from_domain(err: domain::Error) -> Self {
        match err {
            domain::Error::InvalidArgument { msg } => Self::new(ErrorKind::InvalidArgument, msg),
            domain::Error::Unauthenticated => {
                Self::new(ErrorKind::Unauthenticated, "未登录或登录已失效").with_bili_code(-101)
            }
            domain::Error::Csrf => {
                Self::new(ErrorKind::Csrf, "CSRF 校验失败").with_bili_code(-111)
            }
            domain::Error::RiskControl { message } => {
                Self::new(ErrorKind::RiskControl, message).with_bili_code(-412)
            }
            domain::Error::NotFound => {
                Self::new(ErrorKind::NotFound, "资源不存在").with_bili_code(-404)
            }
            domain::Error::RateLimited => {
                Self::new(ErrorKind::RateLimited, "请求过于频繁").with_bili_code(-509)
            }
            domain::Error::Api { code, message } => {
                Self::new(ErrorKind::Internal, message).with_bili_code(code)
            }
        }
    }

    pub fn from_store(err: store::Error) -> Self {
        Self::new(ErrorKind::Storage, err.to_string())
    }

    pub fn from_http(err: http::Error) -> Self {
        match err {
            http::Error::Network(m) => Self::new(ErrorKind::Network, m),
            http::Error::Parse(m) => Self::new(ErrorKind::Parse, m),
            http::Error::Domain(e) => Self::from_domain(e),
            http::Error::Auth(m) => Self::new(ErrorKind::InvalidArgument, m),
        }
    }
}

impl From<domain::Error> for AppError {
    fn from(value: domain::Error) -> Self {
        Self::from_domain(value)
    }
}

impl From<store::Error> for AppError {
    fn from(value: store::Error) -> Self {
        Self::from_store(value)
    }
}

impl From<http::Error> for AppError {
    fn from(value: http::Error) -> Self {
        Self::from_http(value)
    }
}
