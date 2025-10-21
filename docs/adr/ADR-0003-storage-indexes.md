# ADR-0003: Storage & Indexes

**Status:** PROPOSED
**Date:** 2025-10-21
**Deciders:** Sovereign + DAO (if governance active)
**Context:** VaultMesh v5.0 evolution — The Remembrancer storage layer

---

## Context

The Remembrancer (Covenant II: Albedo) requires persistent, tamper-evident storage for:
1. **Receipts** (deployment records, cryptographic proofs)
2. **Artifacts** (SHA-256, GPG sigs, RFC3161 tokens, Merkle proofs)
3. **Merkle trees** (audit log, incremental verification)
4. **Indexes** (by component, version, timestamp, Merkle root)

**Current v4.1 approach:**
- **ROLLUP.txt** (append-only newline-delimited entries)
- **ops/receipts/deploy/*.json** (one file per receipt)
- **docs/REMEMBRANCER.md** (curated human-readable index)

**Requirements for v5.0:**
- ✅ **ACID transactions** (receipts + Merkle updates atomic)
- ✅ **Append-only semantics** (no edit/delete, only new versions)
- ✅ **Cross-platform** (Linux, macOS, Windows, BSD)
- ✅ **Embeddable** (no server process, single file or directory)
- ✅ **Hermetic builds** (bundled, no system SQLite version drift)
- ✅ **Fast queries** (by component, date range, Merkle root)
- ✅ **Tamper-evident** (detect corruption, recover from backups)

---

## Decision

**Provide two storage backends via feature flags:**

| Backend | Use Case | Pros | Cons |
|---------|----------|------|------|
| **rusqlite** (default) | Relational queries, ad-hoc reporting | Mature, SQL, ubiquitous | Larger binary |
| **redb** (optional) | Immutable receipts, MVCC, append-only | Pure Rust, MVCC, copy-on-write | Newer (stable 1.0) |

**Feature flags:**
```toml
[features]
default = ["storage-sqlite"]
storage-sqlite = ["dep:rusqlite"]
storage-redb = ["dep:redb"]
```

**Trait abstraction:**
```rust
pub trait ReceiptStore {
    fn insert(&self, receipt: &Receipt) -> Result<ReceiptId>;
    fn get(&self, id: &ReceiptId) -> Result<Option<Receipt>>;
    fn query(&self, filter: &ReceiptFilter) -> Result<Vec<Receipt>>;
    fn merkle_root(&self) -> Result<[u8; 32]>;
}

// Implementations
impl ReceiptStore for SqliteStore { /* ... */ }
impl ReceiptStore for RedbStore { /* ... */ }
```

---

## Rationale

### Why SQLite (rusqlite)?

**Schema:**
```sql
CREATE TABLE receipts (
    id TEXT PRIMARY KEY,  -- SHA-256 of canonical JSON
    component TEXT NOT NULL,
    version TEXT NOT NULL,
    target TEXT NOT NULL,
    timestamp_utc TEXT NOT NULL,
    ok BOOLEAN NOT NULL,
    sha256 BLOB NOT NULL,
    gpg_signature BLOB,
    rfc3161_token BLOB,
    merkle_proof BLOB,
    canonical_json BLOB NOT NULL,  -- JCS bytes
    created_at INTEGER NOT NULL  -- Unix timestamp
);

CREATE INDEX idx_component ON receipts(component, version);
CREATE INDEX idx_timestamp ON receipts(timestamp_utc);
CREATE INDEX idx_merkle ON receipts(merkle_proof) WHERE merkle_proof IS NOT NULL;

CREATE TABLE merkle_nodes (
    node_hash BLOB PRIMARY KEY,
    left_hash BLOB,
    right_hash BLOB,
    receipt_id TEXT,
    FOREIGN KEY (receipt_id) REFERENCES receipts(id)
);

CREATE TABLE merkle_roots (
    root_hash BLOB PRIMARY KEY,
    computed_at INTEGER NOT NULL,
    receipt_count INTEGER NOT NULL
);
```

**Advantages:**
- ✅ **Mature ecosystem:** 20+ years, battle-tested
- ✅ **SQL queries:** Rich filtering, joins, aggregations
- ✅ **Bundled builds:** `rusqlite` with `bundled` feature compiles SQLite from source
- ✅ **Transaction safety:** ACID, WAL mode for concurrency
- ✅ **Backup trivial:** `.backup` command, or copy `.db` file

**Example usage:**
```rust
use rusqlite::{Connection, params};

let conn = Connection::open("remembrancer.db")?;

// Insert receipt
conn.execute(
    "INSERT INTO receipts (id, component, version, canonical_json, created_at)
     VALUES (?1, ?2, ?3, ?4, ?5)",
    params![id, component, version, canonical, timestamp],
)?;

// Query by component
let mut stmt = conn.prepare(
    "SELECT canonical_json FROM receipts WHERE component = ?1 ORDER BY timestamp_utc DESC"
)?;
let receipts: Vec<Receipt> = stmt.query_map(params![component], |row| {
    let bytes: Vec<u8> = row.get(0)?;
    Ok(serde_json::from_slice(&bytes)?)
})?;
```

---

### Why redb (optional)?

**redb** is a pure-Rust, MVCC, copy-on-write embedded database (like LMDB, but safer).

**Schema (KV-style):**
```rust
use redb::{Database, TableDefinition};

const RECEIPTS: TableDefinition<&str, &[u8]> = TableDefinition::new("receipts");
const INDEX_COMPONENT: TableDefinition<(&str, &str), &str> = TableDefinition::new("idx_component");
const MERKLE_NODES: TableDefinition<&[u8], &[u8]> = TableDefinition::new("merkle_nodes");
const MERKLE_ROOTS: TableDefinition<&[u8], u64> = TableDefinition::new("merkle_roots");

let db = Database::create("remembrancer.redb")?;
let write_txn = db.begin_write()?;
{
    let mut table = write_txn.open_table(RECEIPTS)?;
    table.insert(id.as_str(), canonical_json.as_bytes())?;

    let mut idx = write_txn.open_table(INDEX_COMPONENT)?;
    idx.insert((component, version), id.as_str())?;
}
write_txn.commit()?;
```

**Advantages:**
- ✅ **Pure Rust:** No C dependencies, memory-safe
- ✅ **MVCC:** Readers never block writers
- ✅ **Append-friendly:** Copy-on-write B-trees optimal for immutable receipts
- ✅ **Stable 1.0:** Production-ready as of 2024
- ✅ **Compact:** Smaller binary than SQLite

**Trade-offs:**
- ⚠️ **No SQL:** KV-only, must manage indexes manually
- ⚠️ **Newer:** Less ecosystem maturity than SQLite

---

### Why NOT sled?

**sled** was the previous-generation embedded DB, but:
- ❌ **Maintenance uncertain:** Author stepped back, unclear roadmap
- ❌ **Beta status:** Never hit 1.0
- ❌ **Compatibility breaks:** Several breaking changes across 0.x releases

**redb** is the spiritual successor with stable 1.0 and active maintenance.

---

## Data Layout

### Receipt ID (content-addressed)
```rust
use sha2::{Sha256, Digest};

pub fn receipt_id(receipt: &Receipt) -> ReceiptId {
    let canonical = serde_jcs::to_vec(receipt).unwrap();
    let mut hasher = Sha256::new();
    hasher.update(&canonical);
    ReceiptId(hasher.finalize().into())
}
```

### Merkle Tree Structure
```
Root Hash
├─ Node [0-499]
│  ├─ Node [0-249]
│  │  ├─ Leaf (receipt 0)
│  │  └─ Leaf (receipt 1)
│  └─ Node [250-499]
│     ├─ ...
└─ Node [500-999]
   └─ ...
```

**Storage (SQLite):**
```sql
-- Leaf node
INSERT INTO merkle_nodes (node_hash, receipt_id) VALUES (?, ?);

-- Internal node
INSERT INTO merkle_nodes (node_hash, left_hash, right_hash) VALUES (?, ?, ?);

-- Root update (atomic with receipt insert)
INSERT INTO merkle_roots (root_hash, computed_at, receipt_count) VALUES (?, ?, ?);
```

**Storage (redb):**
```rust
let mut merkle_table = txn.open_table(MERKLE_NODES)?;
merkle_table.insert(node_hash.as_ref(), MerkleNode { left, right, receipt_id }.to_bytes())?;

let mut roots_table = txn.open_table(MERKLE_ROOTS)?;
roots_table.insert(root_hash.as_ref(), receipt_count)?;
```

---

## Consequences

### Positive

✅ **ACID guarantees** (receipt + Merkle update or neither):
```rust
let txn = store.begin_transaction()?;
txn.insert_receipt(&receipt)?;
txn.update_merkle_root(&new_root)?;
txn.commit()?;  // Atomic
```

✅ **Content-addressable receipts** (deduplication automatic):
```rust
let id = receipt_id(&receipt);  // SHA-256 of canonical JSON
if store.get(&id)?.is_some() {
    return Ok(());  // Already stored, idempotent
}
```

✅ **Fast queries:**
```sql
-- All deployments for a component
SELECT * FROM receipts WHERE component = 'oracle' ORDER BY timestamp_utc DESC;

-- Receipts in date range
SELECT * FROM receipts WHERE timestamp_utc BETWEEN '2025-10-01' AND '2025-10-31';

-- Merkle root at specific time
SELECT root_hash FROM merkle_roots WHERE computed_at <= ? ORDER BY computed_at DESC LIMIT 1;
```

✅ **Tamper detection:**
```rust
pub fn verify_merkle_tree(store: &dyn ReceiptStore) -> Result<bool> {
    let receipts = store.query(&ReceiptFilter::All)?;
    let computed_root = build_merkle_tree(&receipts);
    let stored_root = store.merkle_root()?;
    Ok(computed_root == stored_root)
}
```

### Negative

⚠️ **SQLite binary size:** ~1 MB added to release binary (mitigated by compression)

⚠️ **Manual index management for redb:** More code than SQL `CREATE INDEX`

⚠️ **Migration complexity:** Must support importing v4.1 ROLLUP.txt + JSON files

### Neutral

🔄 **Feature flag allows choice:**
```bash
# Default: SQLite
cargo build --release

# Opt into redb
cargo build --release --no-default-features --features storage-redb
```

🔄 **Export format (migration-safe):**
```bash
# Export receipts as newline-delimited JSON (JCS)
vm-cli export --format ndjson > receipts.ndjson

# Import into new storage backend
vm-cli import < receipts.ndjson
```

---

## Covenant Alignment

### II. REPRODUCIBILITY (Albedo)
**Hermetic builds:**
```toml
[dependencies]
rusqlite = { version = "0.30", features = ["bundled"] }  # Compiles SQLite from source
```
No system SQLite version drift → reproducible behavior.

### I. INTEGRITY (Nigredo)
**Tamper-evident storage:**
```rust
// Merkle root recomputed on every query
assert_eq!(store.merkle_root()?, recompute_merkle_root(&receipts)?);
```

### III. FEDERATION (Citrinitas)
**Content-addressed receipts enable merge:**
```rust
// Receipt ID is deterministic (SHA-256 of JCS)
let receipt_a = Receipt { component: "foo", version: "1.0", ... };
let receipt_b = Receipt { component: "foo", version: "1.0", ... };
assert_eq!(receipt_id(&receipt_a), receipt_id(&receipt_b));  // Merge safe
```

---

## Security Considerations

### 1. Prevent SQL Injection
```rust
// SAFE: Parameterized query
conn.execute(
    "SELECT * FROM receipts WHERE component = ?1",
    params![component],
)?;

// UNSAFE: String concatenation (never do this)
let query = format!("SELECT * FROM receipts WHERE component = '{}'", component);
```

### 2. Encrypt Database at Rest (optional)
**SQLCipher integration:**
```toml
rusqlite = { version = "0.30", features = ["bundled", "sqlcipher"] }
```
```rust
let conn = Connection::open("remembrancer.db")?;
conn.execute("PRAGMA key = 'your-encryption-key'", [])?;
```

### 3. Backup Strategy
```rust
// SQLite
let backup = rusqlite::backup::Backup::new(&src, &dest)?;
backup.run_to_completion(5, Duration::from_millis(250), None)?;

// redb
std::fs::copy("remembrancer.redb", "backup/remembrancer.redb")?;
```

---

## Migration from v4.1

**Step 1: Parse existing receipts**
```rust
// Read ops/receipts/deploy/*.json
for entry in glob("ops/receipts/deploy/*.json")? {
    let json = std::fs::read_to_string(entry)?;
    let receipt: Receipt = serde_json::from_str(&json)?;
    store.insert(&receipt)?;
}
```

**Step 2: Parse ROLLUP.txt**
```rust
// Parse newline-delimited entries
for line in std::io::BufReader::new(file).lines() {
    let entry: RollupEntry = parse_rollup_line(&line?)?;
    let receipt = entry.to_receipt()?;
    store.insert(&receipt)?;
}
```

**Step 3: Recompute Merkle root**
```rust
let receipts = store.query(&ReceiptFilter::All)?;
let root = build_merkle_tree(&receipts);
store.update_merkle_root(&root)?;
```

**Step 4: Verify against docs/REMEMBRANCER.md**
```bash
# Extract Merkle root from markdown
EXPECTED=$(awk '/Current Root:/{print $3}' docs/REMEMBRANCER.md | tr -d '`')

# Compare with computed root
COMPUTED=$(vm-cli merkle-root)

if [ "$EXPECTED" != "$COMPUTED" ]; then
  echo "ERROR: Merkle root mismatch!"
  exit 1
fi
```

---

## Testing Strategy

### Unit tests
```rust
#[test]
fn test_receipt_roundtrip() {
    let store = SqliteStore::in_memory().unwrap();
    let receipt = Receipt { component: "test", version: "1.0", ... };
    let id = store.insert(&receipt).unwrap();
    let retrieved = store.get(&id).unwrap().unwrap();
    assert_eq!(receipt, retrieved);
}

#[test]
fn test_merkle_tamper_detection() {
    let store = SqliteStore::in_memory().unwrap();
    store.insert(&receipt1).unwrap();
    store.insert(&receipt2).unwrap();

    // Manually corrupt receipt2
    let conn = store.connection();
    conn.execute("UPDATE receipts SET sha256 = ? WHERE id = ?", params![&[0u8; 32], id2])?;

    // Verify should fail
    assert!(verify_merkle_tree(&store).is_err());
}
```

### Integration tests
```rust
#[test]
fn test_v4_import() {
    let store = SqliteStore::open("test.db").unwrap();
    import_v4_receipts(&store, "tests/fixtures/ops/receipts/deploy").unwrap();

    let receipts = store.query(&ReceiptFilter::Component("oracle")).unwrap();
    assert_eq!(receipts.len(), 3);
}
```

### Property tests
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn receipt_id_is_deterministic(r in any::<Receipt>()) {
        let id1 = receipt_id(&r);
        let id2 = receipt_id(&r);
        prop_assert_eq!(id1, id2);
    }
}
```

---

## Alternatives Considered

### 1. **Flat files (current v4.1 approach)**
- ❌ No ACID (crash during write = corrupt)
- ❌ No indexes (must scan all files)
- ❌ No tamper detection (must recompute Merkle every time)

### 2. **PostgreSQL/MySQL**
- ❌ Server process (not embeddable)
- ❌ System dependency (breaks hermetic builds)
- ❌ Overkill for single-user CLI

### 3. **RocksDB**
- ⚠️ C++ dependency (breaks pure-Rust goal)
- ⚠️ Larger binary (~5 MB)
- ✅ Good for high-throughput (but VaultMesh is append-mostly)

### 4. **sled**
- ❌ Maintenance uncertain, beta status

---

## Dependencies

**vm-remembrancer/Cargo.toml:**
```toml
[features]
default = ["storage-sqlite"]
storage-sqlite = ["dep:rusqlite"]
storage-redb = ["dep:redb"]

[dependencies]
rusqlite = { version = "0.30", features = ["bundled"], optional = true }
redb = { version = "1", optional = true }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_jcs = "0.1"
sha2 = "0.10"
anyhow = "1"
```

---

## References

- [rusqlite](https://github.com/rusqlite/rusqlite)
- [redb](https://github.com/cberner/redb)
- [SQLite](https://sqlite.org/)
- [MVCC (Multi-Version Concurrency Control)](https://en.wikipedia.org/wiki/Multiversion_concurrency_control)
- [Content-Addressed Storage](https://en.wikipedia.org/wiki/Content-addressable_storage)

---

**Decision:** PROCEED with SQLite (default) + redb (optional)
**Next:** ADR-0004 (Canonicalization & Merge)

---

🜄 **Citrinitas:** The yellowing. Indexed memory crystallizes.
