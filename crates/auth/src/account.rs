use crate::cookie::CookieJar;
use crate::slot::AccountSlot;
use domain::id::{AccountId, UserMid};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub id: AccountId,
    pub mid: UserMid,
    pub name: String,
    pub face: String,
    pub cookie_jar: CookieJar,
    pub access_key: Option<String>,
    pub refresh_token: Option<String>,
    pub created_at_ms: i64,
    pub updated_at_ms: i64,
    pub expired: bool,
}

impl Account {
    pub fn to_public(&self) -> domain::AccountPublic {
        domain::AccountPublic {
            id: self.id.clone(),
            mid: self.mid,
            name: self.name.clone(),
            avatar_url: self.face.clone(),
            is_login: !self.expired && self.mid.is_logged_in(),
        }
    }
}

/// Serializable snapshot of the account registry + slot bindings.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountRegistrySnapshot {
    pub version: u32,
    pub accounts: Vec<Account>,
    pub slots: HashMap<AccountSlot, Option<String>>,
    pub active_main: Option<String>,
}

impl Default for AccountRegistrySnapshot {
    fn default() -> Self {
        let mut slots = HashMap::new();
        for s in AccountSlot::ALL {
            slots.insert(s, None);
        }
        Self {
            version: 1,
            accounts: Vec::new(),
            slots,
            active_main: None,
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct AccountRegistry {
    accounts: HashMap<String, Account>,
    slots: HashMap<AccountSlot, Option<String>>,
    active_main: Option<String>,
}

impl AccountRegistry {
    pub fn new() -> Self {
        let mut slots = HashMap::new();
        for s in AccountSlot::ALL {
            slots.insert(s, None);
        }
        Self {
            accounts: HashMap::new(),
            slots,
            active_main: None,
        }
    }

    pub fn from_snapshot(snap: AccountRegistrySnapshot) -> Self {
        let mut reg = Self::new();
        reg.active_main = snap.active_main;
        for (slot, id) in snap.slots {
            reg.slots.insert(slot, id);
        }
        // Ensure all slots exist.
        for s in AccountSlot::ALL {
            reg.slots.entry(s).or_insert(None);
        }
        for account in snap.accounts {
            reg.accounts
                .insert(account.id.as_str().to_string(), account);
        }
        reg
    }

    pub fn to_snapshot(&self) -> AccountRegistrySnapshot {
        AccountRegistrySnapshot {
            version: 1,
            accounts: self.accounts.values().cloned().collect(),
            slots: self.slots.clone(),
            active_main: self.active_main.clone(),
        }
    }

    pub fn list_public(&self) -> Vec<domain::AccountPublic> {
        let mut list: Vec<_> = self.accounts.values().map(Account::to_public).collect();
        list.sort_by(|a, b| a.name.cmp(&b.name));
        list
    }

    pub fn is_empty(&self) -> bool {
        self.accounts.is_empty()
    }

    pub fn insert(&mut self, account: Account) {
        let id = account.id.as_str().to_string();
        if self.active_main.is_none() {
            self.active_main = Some(id.clone());
            for s in AccountSlot::ALL {
                self.slots.insert(s, Some(id.clone()));
            }
        }
        self.accounts.insert(id, account);
    }

    /// Insert and bind all empty slots to this account (does not overwrite filled slots).
    pub fn insert_and_fill_empty_slots(&mut self, account: Account) {
        let id = account.id.as_str().to_string();
        self.accounts.insert(id.clone(), account);
        if self.active_main.is_none() {
            self.active_main = Some(id.clone());
        }
        for s in AccountSlot::ALL {
            let entry = self.slots.entry(s).or_insert(None);
            if entry.is_none() {
                *entry = Some(id.clone());
            }
        }
    }

    pub fn remove(&mut self, id: &str) -> Option<Account> {
        let removed = self.accounts.remove(id);
        if self.active_main.as_deref() == Some(id) {
            self.active_main = self.accounts.keys().next().cloned();
        }
        for slot in self.slots.values_mut() {
            if slot.as_deref() == Some(id) {
                *slot = self.active_main.clone();
            }
        }
        removed
    }

    pub fn account_for(&self, slot: AccountSlot) -> Option<&Account> {
        let id = self.slots.get(&slot).and_then(|x| x.as_ref())?;
        self.accounts.get(id)
    }

    pub fn account_for_mut(&mut self, slot: AccountSlot) -> Option<&mut Account> {
        let id = self
            .slots
            .get(&slot)
            .and_then(|x| x.as_ref())
            .cloned()?;
        self.accounts.get_mut(&id)
    }

    pub fn set_slot(&mut self, slot: AccountSlot, account_id: Option<&str>) {
        self.slots.insert(slot, account_id.map(str::to_string));
    }

    pub fn active_main(&self) -> Option<&Account> {
        self.active_main
            .as_ref()
            .and_then(|id| self.accounts.get(id))
    }

    pub fn get(&self, id: &str) -> Option<&Account> {
        self.accounts.get(id)
    }

    pub fn get_mut(&mut self, id: &str) -> Option<&mut Account> {
        self.accounts.get_mut(id)
    }

    pub fn mark_expired(&mut self, id: &str) {
        if let Some(a) = self.accounts.get_mut(id) {
            a.expired = true;
            a.updated_at_ms = now_ms();
        }
    }
}

pub fn now_ms() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use domain::id::UserMid;

    fn sample_account(name: &str) -> Account {
        let now = now_ms();
        Account {
            id: AccountId::new(),
            mid: UserMid(1),
            name: name.into(),
            face: String::new(),
            cookie_jar: CookieJar::new(),
            access_key: None,
            refresh_token: None,
            created_at_ms: now,
            updated_at_ms: now,
            expired: false,
        }
    }

    #[test]
    fn insert_fills_slots() {
        let mut reg = AccountRegistry::new();
        let a = sample_account("u1");
        let id = a.id.as_str().to_string();
        reg.insert(a);
        assert_eq!(
            reg.account_for(AccountSlot::Main)
                .map(|a| a.id.as_str()),
            Some(id.as_str())
        );
        assert_eq!(
            reg.account_for(AccountSlot::Video)
                .map(|a| a.id.as_str()),
            Some(id.as_str())
        );
    }

    #[test]
    fn snapshot_roundtrip() {
        let mut reg = AccountRegistry::new();
        reg.insert(sample_account("u1"));
        let snap = reg.to_snapshot();
        let restored = AccountRegistry::from_snapshot(snap);
        assert_eq!(restored.list_public().len(), 1);
        assert!(restored.account_for(AccountSlot::Main).is_some());
    }
}
