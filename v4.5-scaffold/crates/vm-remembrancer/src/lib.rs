use anyhow::Result;
use vm_core::types::Receipt;
pub trait ReceiptStore {
    fn put(&mut self, r: &Receipt) -> Result<()>;
    fn get(&self, id: &str) -> Result<Option<Receipt>>;
    fn by_component(&self, c: &str) -> Result<Vec<Receipt>>;
    fn all(&self) -> Result<Vec<Receipt>>;
}
#[cfg(feature = "sqlite")]
pub mod sqlite_store {
    use super::*;
    use rusqlite::{Connection, params};
    pub struct SqliteStore {
        conn: Connection,
    }
    impl SqliteStore {
        pub fn open(p: &str) -> Result<Self> {
            let c = Connection::open(p)?;
            c.execute_batch("CREATE TABLE IF NOT EXISTS receipts(id TEXT PRIMARY KEY, component TEXT NOT NULL, version TEXT NOT NULL, jcs BLOB NOT NULL); CREATE INDEX IF NOT EXISTS idx_component ON receipts(component);")?;
            Ok(Self { conn: c })
        }
    }
    impl ReceiptStore for SqliteStore {
        fn put(&mut self, r: &Receipt) -> Result<()> {
            let j = serde_jcs::to_vec(r)?;
            self.conn.execute(
                "INSERT OR REPLACE INTO receipts(id,component,version,jcs) VALUES (?1,?2,?3,?4)",
                params![r.id, r.component, r.version, j],
            )?;
            Ok(())
        }
        fn get(&self, id: &str) -> Result<Option<Receipt>> {
            let mut st = self.conn.prepare("SELECT jcs FROM receipts WHERE id=?1")?;
            let mut rows = st.query(params![id])?;
            if let Some(row) = rows.next()? {
                let j: Vec<u8> = row.get(0)?;
                return Ok(Some(serde_json::from_slice(&j)?));
            }
            Ok(None)
        }
        fn by_component(&self, c: &str) -> Result<Vec<Receipt>> {
            let mut st = self
                .conn
                .prepare("SELECT jcs FROM receipts WHERE component=?1 ORDER BY id DESC")?;
            let rows = st.query_map(params![c], |row| {
                let j: Vec<u8> = row.get(0)?;
                Ok(serde_json::from_slice::<Receipt>(&j).unwrap())
            })?;
            Ok(rows.filter_map(Result::ok).collect())
        }
        fn all(&self) -> Result<Vec<Receipt>> {
            let mut st = self.conn.prepare("SELECT jcs FROM receipts ORDER BY id DESC")?;
            let rows = st.query_map([], |row| {
                let j: Vec<u8> = row.get(0)?;
                Ok(serde_json::from_slice::<Receipt>(&j).unwrap())
            })?;
            Ok(rows.filter_map(Result::ok).collect())
        }
    }
}
#[cfg(feature = "redb")]
pub mod redb_store {
    use super::*;
    use redb::{Database, TableDefinition};
    const T: TableDefinition<&str, Vec<u8>> = TableDefinition::new("receipts");
    pub struct RedbStore {
        db: Database,
    }
    impl RedbStore {
        pub fn open(p: &str) -> Result<Self> {
            Ok(Self { db: Database::create(p)? })
        }
    }
    impl ReceiptStore for RedbStore {
        fn put(&mut self, r: &Receipt) -> Result<()> {
            let j = serde_jcs::to_vec(r)?;
            let tx = self.db.begin_write()?;
            {
                let mut t = tx.open_table(T)?;
                t.insert(r.id.as_str(), j)?;
            }
            tx.commit()?;
            Ok(())
        }
        fn get(&self, id: &str) -> Result<Option<Receipt>> {
            let tx = self.db.begin_read()?;
            let t = tx.open_table(T)?;
            if let Some(v) = t.get(id)? {
                return Ok(Some(serde_json::from_slice(v.value())?));
            }
            Ok(None)
        }
        fn by_component(&self, c: &str) -> Result<Vec<Receipt>> {
            let tx = self.db.begin_read()?;
            let t = tx.open_table(T)?;
            let mut out = Vec::new();
            for r in t.iter()? {
                let (_k, v) = r?;
                let rec: Receipt = serde_json::from_slice(v.value())?;
                if rec.component == c {
                    out.push(rec);
                }
            }
            Ok(out)
        }
        fn all(&self) -> Result<Vec<Receipt>> {
            let tx = self.db.begin_read()?;
            let t = tx.open_table(T)?;
            let mut out = Vec::new();
            for r in t.iter()? {
                let (_k, v) = r?;
                out.push(serde_json::from_slice(v.value())?);
            }
            Ok(out)
        }
    }
}
