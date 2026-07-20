# 存储设计（`store`）

> 状态：草案  
> 安全原则：凭据不出 Rust；Flutter 不落明文 Cookie

---

## 1. 职责

- 账号密钥与 Cookie jar 持久化。
- 槽位绑定、公开资料缓存。
- 播放进度、设置项、可选缓存元数据。
- 提供 `data_dir` 下的路径约定与迁移版本。

---

## 2. 目录布局

```text
{data_dir}/                          # bootstrap 传入，如 ~/.local/share/nextpili
  meta.json                          # schema_version, install_id
  db.sqlite                          # 主库（推荐）
  secrets/                           # 或走 OS keyring，见 §4
    {account_id}.bin                 # 加密 blob（若不用 keyring）
  cache/                             # 也可指向 cache_dir
    images/                          # 可选；图片也可用 Flutter 缓存
```

| 路径 | 内容 | 可否删 |
|------|------|--------|
| `db.sqlite` | 账号元数据、设置、进度 | 删则丢本地状态 |
| `secrets/*` | Cookie / access_key | 删则需重新登录 |
| `cache/` | 可重建 | 可随时清 |

`cache_dir` 与 `data_dir` 分离时，缓存只写 `cache_dir`。

---

## 3. SQLite Schema（草案）

```sql
-- schema_version 存在 meta 表
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE accounts (
  id            TEXT PRIMARY KEY,  -- AccountId
  mid           INTEGER NOT NULL,
  name          TEXT NOT NULL DEFAULT '',
  face          TEXT NOT NULL DEFAULT '',
  is_valid      INTEGER NOT NULL DEFAULT 1,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);

-- 槽位：main/heartbeat/recommend/video → account_id
CREATE TABLE account_slots (
  slot        TEXT PRIMARY KEY,    -- 'main' | ...
  account_id  TEXT REFERENCES accounts(id) ON DELETE SET NULL
);

CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL              -- JSON 值
);

CREATE TABLE playback_progress (
  bvid          TEXT NOT NULL,
  cid           INTEGER NOT NULL,
  position_ms   INTEGER NOT NULL,
  duration_ms   INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (bvid, cid)
);

-- Cookie 等敏感数据：见 secrets 表或外置
CREATE TABLE account_secrets (
  account_id    TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  -- 若整包加密：
  blob          BLOB NOT NULL,
  -- 或 keyring 引用：
  keyring_ref   TEXT
);
```

迁移：`meta.schema_version` 单调递增；启动时跑 migrate。  
**禁止**破坏性迁移静默丢密钥而不提示。

---

## 4. 密钥存放策略

| 方案 | 适用 | 说明 |
|------|------|------|
| **A. OS Keyring** | 桌面优先推荐 | `secret-service` / Windows Credential / macOS Keychain；存整包 cookie JSON |
| **B. 本地加密文件** | keyring 不可用时回落 | 应用熵 + 机相关 key；威胁模型为「防普通误读」非防同机恶意 root |
| **C. 明文** | 仅 debug 编译 | `cfg(debug)` 可开关，release 禁止 |

接口：

```text
trait SecretStore {
  fn put(account_id, secrets: AccountSecrets) -> Result<()>;
  fn get(account_id) -> Result<Option<AccountSecrets>>;
  fn delete(account_id) -> Result<()>;
}

AccountSecrets { cookies: SerializedJar, access_key: Option<String> }
```

`list_accounts` **只读** `accounts` 表公开字段，永不返回 secrets 给 FFI。

---

## 5. 设置项归属

| 键示例 | 存哪 | 原因 |
|--------|------|------|
| `theme` / `locale` | **可** Flutter 本地或 Rust settings | UI 向；Rust 不依赖也能画 |
| `preferred_qn` / `danmaku_opacity` | **建议 Rust settings** | 播放与策略在 Rust 使用 |
| `proxy_url` | Rust | HTTP 客户端 |
| `slot` 绑定 | Rust `account_slots` | 鉴权核心 |
| Cookie | Rust secrets | 安全 |

**建议约定（拍板）**：

1. **凡影响协议/播放默认策略的设置** → Rust `settings` 表；Flutter 通过 `get_settings` / `set_setting`。  
2. **纯 UI 皮肤** → Flutter `shared_preferences` 亦可；若希望单一备份出口，可后期统一进 Rust。  
3. MVP：主题可留 Flutter；`preferred_qn`、proxy、多账号槽必须 Rust。

---

## 6. 播放进度

- 主键 `(bvid, cid)`。  
- 写入节流：≥ 5s 或每次 pause/dispose。  
- 与服务端历史：**服务端为准**时可启动后拉取覆盖；冲突策略：`max(updated_at)` 或「服务端优先」。MVP 可只本地。

---

## 7. 并发

- 单写者连接 + `Mutex`，或 `sqlx` 池 + WAL。  
- 禁止在持有 DB 锁时做网络。  
- 密钥写入与 accounts 行同一逻辑事务（先写 secret 成功再标 valid）。

---

## 8. 备份与导出

- **导出账号**：显式用户操作 + 确认；生成加密包或 Cookie 文本；默认不做。  
- **导入**：见 auth `import_cookies`。  
- 备份文件不进日志、不进崩溃上报。

---

## 9. 测试

- 使用 `tempfile` 目录跑迁移与 CRUD。  
- SecretStore 可用 `MemorySecretStore` 测 registry。  
- 不测真实 keyring（CI 无服务时 skip）。

---

## 10. 模块文件建议

```text
store/
  src/
    lib.rs
    paths.rs
    db.rs
    migrate.rs
    accounts.rs
    settings.rs
    progress.rs
    secret.rs
    secret_keyring.rs
    secret_file.rs
```
