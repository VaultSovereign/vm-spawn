// vault-law policy: Akash treaty enforcement (WASM-friendly core)
// Build target: wasm32-unknown-unknown

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Clone)]
pub struct Treaty {
    pub treaty_id: String,
    pub regions: Vec<String>,
    pub quota_gpu_hours_total: u32,        // e.g., 10000
    pub quota_gpu_hours_daily_per_tenant: u32, // e.g., 100
    pub min_reputation: u8,                // e.g., 60
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Order {
    pub tenant_id: String,
    pub region: String,
    pub gpu_hours_requested: u32,
    pub nonce: String,
    pub signature_b64: String, // vm-httpsig:ed25519 base64
    pub tenant_reputation: u8, // passed from ledger/oracle
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Accumulators {
    pub treaty_used_total: u32,
    pub day: String, // YYYY-MM-DD
    pub per_tenant_today: HashMap<String, u32>,
    pub seen_nonces: HashMap<String, bool>, // replay protection (24h TTL externally)
}

#[derive(Serialize, Deserialize)]
pub struct Decision {
    pub allow: bool,
    pub reason: String,
}

#[unsafe(no_mangle)]
pub extern "C" fn authorize_json(ptr: *const u8, len: usize) -> *mut u8 {
    // Expects a JSON with { treaty, order, acc }
    let input = unsafe { std::slice::from_raw_parts(ptr, len) };
    let ctx: serde_json::Value = serde_json::from_slice(input).unwrap_or_default();

    let treaty: Treaty = serde_json::from_value(ctx["treaty"].clone()).unwrap();
    let mut acc: Accumulators = serde_json::from_value(ctx["acc"].clone()).unwrap_or(Accumulators{
        treaty_used_total: 0, day: "".into(), per_tenant_today: HashMap::new(), seen_nonces: HashMap::new()
    });
    let order: Order = serde_json::from_value(ctx["order"].clone()).unwrap();

    // 1) Region lock
    if !treaty.regions.contains(&order.region) {
        return out(Decision{ allow:false, reason: format!("region {} not allowed", order.region) });
    }
    // 2) Nonce replay guard (simple in-mem check; production should TTL in gateway)
    if acc.seen_nonces.get(&order.nonce).copied().unwrap_or(false) {
        return out(Decision{ allow:false, reason: "replay nonce".into() });
    }
    // 3) Reputation threshold
    if order.tenant_reputation < treaty.min_reputation {
        return out(Decision{ allow:false, reason: "low reputation".into() });
    }
    // 4) Daily per-tenant cap
    let used_today = *acc.per_tenant_today.get(&order.tenant_id).unwrap_or(&0);
    if used_today + order.gpu_hours_requested > treaty.quota_gpu_hours_daily_per_tenant {
        return out(Decision{ allow:false, reason: "daily tenant cap exceeded".into() });
    }
    // 5) Treaty total cap
    if acc.treaty_used_total + order.gpu_hours_requested > treaty.quota_gpu_hours_total {
        return out(Decision{ allow:false, reason: "treaty total cap exceeded".into() });
    }

    // Mutate accumulators (host should persist)
    acc.per_tenant_today.insert(order.tenant_id.clone(), used_today + order.gpu_hours_requested);
    acc.treaty_used_total += order.gpu_hours_requested;
    acc.seen_nonces.insert(order.nonce.clone(), true);

    out(Decision{ allow:true, reason:"ok".into() })
}

fn out<T: Serialize>(val: T) -> *mut u8 {
    let bytes = serde_json::to_vec(&val).unwrap();
    let mut boxed = bytes.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}
