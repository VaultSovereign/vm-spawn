
import json, csv, math, random
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
from collections import defaultdict
from datetime import datetime
import os

BASE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(BASE, ".."))

# Load configs
with open(os.path.join(ROOT, "config", "providers.json")) as f:
    providers_cfg = json.load(f)
with open(os.path.join(ROOT, "config", "workloads.json")) as f:
    workloads_cfg = json.load(f)

# --- Core structures (repeat minimal code) ---
@dataclass
class ProviderState:
    id: str
    name: str
    bridge: str
    regions: List[str]
    gpu_types: List[str]
    credits_per_hour: Dict[str, float]
    price_usd_per_hour: Dict[str, float]
    base_latency_ms: float
    capacity_gpu_hours_per_step: float
    reputation: float
    active: bool = True
    dynamic_latency_ms: float = 0.0
    dynamic_capacity_multiplier: float = 1.0
    dynamic_price_multiplier: float = 1.0
    dynamic_rep_delta: float = 0.0
    def effective_latency(self) -> float:
        return max(1.0, self.base_latency_ms + self.dynamic_latency_ms)
    def effective_capacity(self) -> float:
        return max(0.0, self.capacity_gpu_hours_per_step * self.dynamic_capacity_multiplier)
    def effective_price(self, gpu_type: str) -> float:
        base = self.price_usd_per_hour.get(gpu_type, 10.0)
        return base * self.dynamic_price_multiplier
    def effective_reputation(self) -> float:
        return max(0.0, min(100.0, self.reputation + self.dynamic_rep_delta))

@dataclass
class Request:
    step: int
    tenant_id: str
    region: str
    workload_type: str
    gpu_type: str
    gpu_hours: float
    max_price: float
    max_latency_ms: float
    min_reputation: float
    weights: Dict[str, float]

@dataclass
class RoutingDecision:
    step: int
    tenant_id: str
    workload_type: str
    gpu_type: str
    provider_id: Optional[str]
    accepted: bool
    price_usd_per_hour: float = 0.0
    credits_cost: float = 0.0
    latency_ms: float = 0.0
    reason: str = ""

class Router:
    def __init__(self, providers: Dict[str, ProviderState], usd_per_credit: float):
        self.providers = providers
        self.usd_per_credit = usd_per_credit
        self.capacity_remaining = {pid: providers[pid].effective_capacity() for pid in providers}
    def reset_step(self):
        self.capacity_remaining = {pid: self.providers[pid].effective_capacity() for pid in self.providers}
    def route(self, req: Request) -> RoutingDecision:
        candidates = []
        for pid, p in self.providers.items():
            if not p.active:
                continue
            if req.region not in p.regions and "global" not in p.regions:
                continue
            if req.gpu_type not in p.gpu_types:
                continue
            if p.effective_latency() > req.max_latency_ms:
                continue
            if p.effective_reputation() < req.min_reputation:
                continue
            price = p.effective_price(req.gpu_type)
            if price > req.max_price:
                continue
            if self.capacity_remaining.get(pid, 0.0) < req.gpu_hours:
                continue
            candidates.append(pid)
        if not candidates:
            return RoutingDecision(step=req.step, tenant_id=req.tenant_id, workload_type=req.workload_type,
                                   gpu_type=req.gpu_type, provider_id=None, accepted=False, reason="no_viable_provider")
        scored = []
        for pid in candidates:
            p = self.providers[pid]
            price = p.effective_price(req.gpu_type)
            latency = p.effective_latency()
            rep = p.effective_reputation()
            availability = self.capacity_remaining[pid] / max(1e-6, p.effective_capacity())
            price_score = 1.0 / max(price, 1e-6)
            latency_score = 1.0 / max(latency, 1e-6)
            reputation_score = rep / 100.0
            availability_score = availability
            total = (price_score * req.weights["price"] +
                     latency_score * req.weights["latency"] +
                     reputation_score * req.weights["reputation"] +
                     availability_score * req.weights["availability"])
            scored.append((total, pid, price, latency))
        scored.sort(reverse=True, key=lambda x: x[0])
        _, chosen_pid, chosen_price, chosen_latency = scored[0]
        self.capacity_remaining[chosen_pid] -= req.gpu_hours
        p = self.providers[chosen_pid]
        credits_per_hour = p.credits_per_hour.get(req.gpu_type, 1.0)
        credits_cost = credits_per_hour * req.gpu_hours
        return RoutingDecision(step=req.step, tenant_id=req.tenant_id, workload_type=req.workload_type,
                               gpu_type=req.gpu_type, provider_id=chosen_pid, accepted=True,
                               price_usd_per_hour=chosen_price, credits_cost=credits_cost,
                               latency_ms=chosen_latency, reason="ok")

class ScenarioEngine:
    def __init__(self, providers: Dict[str, ProviderState], scenarios: List[Dict[str, Any]]):
        self.providers = providers
        self.scenarios = scenarios
        self.expirations: List[Dict[str, Any]] = []
    def apply_events(self, step: int):
        new_exp = []
        for e in self.expirations:
            if step >= e["expire_at"]:
                p = self.providers[e["provider_id"]]
                if e["type"] == "outage":
                    p.active = True
                elif e["type"] == "latency_spike":
                    p.dynamic_latency_ms -= e["delta_ms"]
                elif e["type"] == "capacity_surge":
                    p.dynamic_capacity_multiplier /= e["multiplier"]
                elif e["type"] == "price_spike":
                    p.dynamic_price_multiplier /= e["multiplier"]
                elif e["type"] == "reputation_drop":
                    p.dynamic_rep_delta -= e["delta"]
            else:
                new_exp.append(e)
        self.expirations = new_exp
        for ev in self.scenarios:
            if ev["step"] == step:
                pid = ev["provider_id"]
                p = self.providers[pid]
                if ev["event"] == "outage":
                    p.active = False
                    self.expirations.append({"type":"outage","provider_id":pid,"expire_at": step + ev.get("duration",5)})
                elif ev["event"] == "latency_spike":
                    p.dynamic_latency_ms += ev["delta_ms"]
                    self.expirations.append({"type":"latency_spike","provider_id":pid,"delta_ms":ev["delta_ms"],"expire_at": step + ev.get("duration",10)})
                elif ev["event"] == "capacity_surge":
                    p.dynamic_capacity_multiplier *= ev["multiplier"]
                    self.expirations.append({"type":"capacity_surge","provider_id":pid,"multiplier":ev["multiplier"],"expire_at": step + ev.get("duration",10)})
                elif ev["event"] == "price_spike":
                    p.dynamic_price_multiplier *= ev["multiplier"]
                    self.expirations.append({"type":"price_spike","provider_id":pid,"multiplier":ev["multiplier"],"expire_at": step + ev.get("duration",10)})
                elif ev["event"] == "reputation_drop":
                    p.dynamic_rep_delta += ev["delta"]
                    self.expirations.append({"type":"reputation_drop","provider_id":pid,"delta":ev["delta"],"expire_at": step + ev.get("duration",10)})

def choice_weighted(d: Dict[str,float]) -> str:
    r = random.random()
    acc = 0.0
    for k,v in d.items():
        acc += v
        if r <= acc:
            return k
    return list(d.keys())[-1]

def write_csv(path, rows):
    if not rows: return
    keys = list(rows[0].keys())
    import csv
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for r in rows:
            w.writerow(r)

def run():
    # Allow environment variable overrides for seed and steps
    seed = int(os.environ.get("SEED", workloads_cfg["simulation"]["seed"]))
    steps = int(os.environ.get("STEPS", workloads_cfg["simulation"]["steps"]))

    random.seed(seed)
    providers: Dict[str,ProviderState] = {}
    for p in providers_cfg["providers"]:
        providers[p["id"]] = ProviderState(
            id=p["id"], name=p["name"], bridge=p["bridge"], regions=p["regions"],
            gpu_types=p["gpu_types"], credits_per_hour=p["credits_per_hour"],
            price_usd_per_hour=p["base_price_usd_per_hour"], base_latency_ms=p["base_latency_ms"],
            capacity_gpu_hours_per_step=p["capacity_gpu_hours_per_step"], reputation=p["reputation"]
        )
    usd_per_credit = providers_cfg["usd_per_credit"]
    scenario = ScenarioEngine(providers, workloads_cfg.get("scenarios", []))
    router = Router(providers, usd_per_credit)
    out_dir = os.path.join(ROOT, "out")
    os.makedirs(out_dir, exist_ok=True)

    provider_metrics_rows = []
    routing_rows = []
    step_rows = []

    for step in range(steps):
        scenario.apply_events(step)
        router.reset_step()
        total_requests = 0; routed = 0; dropped = 0
        sum_cost_usd = 0.0; sum_latency = 0.0
        credits_minted = 0.0; credits_burned = 0.0

        for pid, p in providers.items():
            provider_metrics_rows.append({
                "step": step, "provider_id": pid, "active": int(p.active),
                "effective_capacity": router.providers[pid].effective_capacity(),
                "latency_ms": router.providers[pid].effective_latency(),
                "price_A100": router.providers[pid].effective_price("A100"),
                "reputation": router.providers[pid].effective_reputation()
            })

        for tenant in workloads_cfg["tenants"]:
            nreq = max(0, int(random.gauss(tenant["avg_requests_per_step"], 2)))
            budget_remaining = tenant["budget_usd_per_step"]
            for _ in range(nreq):
                wl = choice_weighted(tenant["mix"])
                profile = workloads_cfg["workload_profiles"][wl]
                gpu_type = profile["gpu_type"]
                gpu_hours = random.uniform(profile["gpu_hours"][0], profile["gpu_hours"][1])
                max_price = max(0.1, min(10.0, budget_remaining / max(gpu_hours,1e-6)))
                req = Request(step=step, tenant_id=tenant["id"], region=tenant["region"], workload_type=wl,
                              gpu_type=gpu_type, gpu_hours=gpu_hours, max_price=max_price,
                              max_latency_ms=tenant["max_latency_ms"], min_reputation=tenant["min_reputation"],
                              weights=tenant["weights"])
                total_requests += 1
                decision = router.route(req)
                if decision.accepted:
                    routed += 1
                    cost = decision.price_usd_per_hour * gpu_hours
                    if budget_remaining - cost < -1e-6:
                        decision.accepted = False; decision.reason = "budget_exceeded"; dropped += 1
                    else:
                        budget_remaining -= cost
                        sum_cost_usd += cost
                        sum_latency += decision.latency_ms
                        credits_minted += decision.credits_cost
                        credits_burned += decision.credits_cost
                else:
                    dropped += 1
                routing_rows.append({
                    "step": step, "tenant_id": req.tenant_id, "workload_type": req.workload_type,
                    "gpu_type": req.gpu_type, "gpu_hours": round(req.gpu_hours,3),
                    "provider_id": decision.provider_id or "", "accepted": int(decision.accepted),
                    "price_usd_per_hour": round(decision.price_usd_per_hour,4),
                    "latency_ms": round(decision.latency_ms,1), "reason": decision.reason
                })
        avg_cost = (sum_cost_usd / max(routed,1)) if routed else 0.0
        avg_latency = (sum_latency / max(routed,1)) if routed else 0.0
        fill_rate = routed / max(total_requests,1)
        step_rows.append({
            "step": step, "total_requests": total_requests, "routed": routed, "dropped": dropped,
            "fill_rate": round(fill_rate,4), "avg_cost_usd_per_request": round(avg_cost,4),
            "avg_latency_ms": round(avg_latency,1), "credits_minted": round(credits_minted,3),
            "credits_burned": round(credits_burned,3)
        })

    write_csv(os.path.join(out_dir, "provider_metrics_over_time.csv"), provider_metrics_rows)
    write_csv(os.path.join(out_dir, "routing_decisions.csv"), routing_rows)
    write_csv(os.path.join(out_dir, "step_metrics.csv"), step_rows)
    print("[OK] Simulation complete. See out/*.csv")

if __name__ == "__main__":
    run()
