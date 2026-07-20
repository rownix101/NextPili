use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error("io: {0}")]
    Io(String),
    #[error("serialize: {0}")]
    Serialize(String),
}

impl Error {
    pub fn io(err: impl ToString) -> Self {
        Self::Io(err.to_string())
    }

    pub fn ser(err: impl ToString) -> Self {
        Self::Serialize(err.to_string())
    }
}

pub type Result<T> = std::result::Result<T, Error>;
