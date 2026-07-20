use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error("invalid media payload: {0}")]
    Invalid(String),
}

pub type Result<T> = std::result::Result<T, Error>;
