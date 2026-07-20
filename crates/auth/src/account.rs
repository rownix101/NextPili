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

    pub fn list_public(&self) -> Vec<domain::AccountPublic> {
        self.accounts.values().map(Account::to_public).collect()
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

    pub fn account_for(&self, slot: AccountSlot) -> Option<&Account> {
        let id = self.slots.get(&slot).and_then(|x| x.as_ref())?;
        self.accounts.get(id)
    }

    pub fn set_slot(&mut self, slot: AccountSlot, account_id: Option<&str>) {
        self.slots
            .insert(slot, account_id.map(str::to_string));
    }

    pub fn get(&self, id: &str) -> Option<&Account> {
        self.accounts.get(id)
    }

    pub fn get_mut(&mut self, id: &str) -> Option<&mut Account> {
        self.accounts.get_mut(id)
    }
}
