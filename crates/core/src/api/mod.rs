//! Public FFI API surface (hand-written; FRB generates bindings from these).

pub mod simple;

pub use simple::{api_version, bootstrap, ping, ApiVersion, BootstrapConfig};
