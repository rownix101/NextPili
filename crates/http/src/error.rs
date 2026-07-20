use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error("network: {0}")]
    Network(String),
    #[error("parse: {0}")]
    Parse(String),
    #[error(transparent)]
    Domain(#[from] domain::Error),
    #[error("auth: {0}")]
    Auth(String),
}

pub type Result<T> = std::result::Result<T, Error>;
