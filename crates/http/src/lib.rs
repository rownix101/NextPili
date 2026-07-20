//! HTTP transport layer for Bilibili APIs.

pub mod client;
pub mod endpoints;
pub mod error;
pub mod middleware;

pub use client::{BiliClient, ClientConfig};
pub use error::{Error, Result};
