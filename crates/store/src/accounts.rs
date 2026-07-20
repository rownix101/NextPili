use crate::error::{Error, Result};
use auth::{AccountRegistry, AccountRegistrySnapshot};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AccountsFile {
    #[serde(flatten)]
    registry: AccountRegistrySnapshot,
}

/// Load / save account registry as JSON (secrets stay on disk under data_dir).
#[derive(Debug)]
pub struct AccountsStore {
    path: PathBuf,
}

impl AccountsStore {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn load(&self) -> Result<AccountRegistry> {
        if !self.path.exists() {
            return Ok(AccountRegistry::new());
        }
        let raw = std::fs::read_to_string(&self.path).map_err(Error::io)?;
        let file: AccountsFile = serde_json::from_str(&raw).map_err(Error::ser)?;
        Ok(AccountRegistry::from_snapshot(file.registry))
    }

    pub fn save(&self, registry: &AccountRegistry) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent).map_err(Error::io)?;
        }
        let file = AccountsFile {
            registry: registry.to_snapshot(),
        };
        let raw = serde_json::to_string_pretty(&file).map_err(Error::ser)?;
        // Atomic-ish replace: write temp then rename.
        let tmp = self.path.with_extension("json.tmp");
        std::fs::write(&tmp, raw).map_err(Error::io)?;
        std::fs::rename(&tmp, &self.path).map_err(Error::io)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use auth::{now_ms, Account, CookieJar};
    use domain::id::{AccountId, UserMid};
    use tempfile::tempdir;

    #[test]
    fn save_load_roundtrip() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("accounts.json");
        let store = AccountsStore::new(&path);

        let mut reg = AccountRegistry::new();
        let mut jar = CookieJar::new();
        jar.set("SESSDATA", "secret");
        jar.set("bili_jct", "csrf");
        let now = now_ms();
        reg.insert(Account {
            id: AccountId::new(),
            mid: UserMid(42),
            name: "tester".into(),
            face: "https://example/face".into(),
            cookie_jar: jar,
            access_key: Some("ak".into()),
            refresh_token: Some("rt".into()),
            created_at_ms: now,
            updated_at_ms: now,
            expired: false,
        });
        store.save(&reg).unwrap();

        let loaded = store.load().unwrap();
        let acc = loaded.active_main().unwrap();
        assert_eq!(acc.mid.get(), 42);
        assert_eq!(acc.cookie_jar.sessdata(), Some("secret"));
        assert_eq!(acc.access_key.as_deref(), Some("ak"));
    }
}
