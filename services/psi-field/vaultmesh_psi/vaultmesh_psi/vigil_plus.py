
import os, json, hashlib, argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from .psi_core import Params, PsiEngine
from .backends.simple import SimpleBackend
from .adversary import AdversarialEnv

class TaskCollector:
    def __init__(self): self.tasks=[]
    def add(self, t): self.tasks.append(t)
    def write(self, path):
        with open(path, "w", encoding="utf-8") as f:
            for t in self.tasks: f.write(json.dumps(t)+"\n"); return path

class VoidGuardianPP:
    def __init__(self, collector, pe_hi=2.0, psi_lo=0.25, psi_recover=0.85, h_hi=2.2,
                 burst_cycles=6, noise_boost=0.06, cf_cycles=6, cf_rollouts=16, cf_horizon=3.0):
        self.collector=collector; self.pe_hi=pe_hi; self.psi_lo=psi_lo; self.psi_recover=psi_recover; self.h_hi=h_hi
        self.burst_cycles=burst_cycles; self.noise_boost=noise_boost
        self.cf_cycles=cf_cycles; self.cf_rollouts=cf_rollouts; self.cf_horizon=cf_horizon
        self.cooldowns={}; self.cf_until={}
    def inbound(self, x, engine):
        eid=id(engine)
        if not hasattr(engine, "_guardian_init"):
            engine._guardian_init=True; engine._lambda_default=engine.params.lambda_; engine._noise_default=getattr(engine.backend,"noise",0.02)
            engine._N_default=engine.params.N; engine._H_default=engine.params.H
        k=getattr(engine,"k",0)
        if self.cf_until.get(eid,-1)>=k:
            engine.params.N=max(engine.params.N,self.cf_rollouts); engine.params.H=max(engine.params.H,self.cf_horizon)
        else:
            engine.params.N=engine._N_default; engine.params.H=engine._H_default
        x=np.asarray(x,dtype=float); x=np.clip(x,-6.0,6.0); x=(x-x.mean())/(x.std()+1e-6); return x
    def outbound(self, stats, engine, engine_idx=None):
        eid=id(engine); Psi=stats["Psi"]; PE=stats["PE"]; H=stats["H"]; k=stats["k"]
        if not hasattr(engine,"_lambda_default"):
            engine._lambda_default=engine.params.lambda_; engine._noise_default=getattr(engine.backend,"noise",0.02)
            engine._N_default=engine.params.N; engine._H_default=engine.params.H
        threat=(PE>self.pe_hi) or (Psi<self.psi_lo) or (H>self.h_hi)
        if threat:
            engine._red_flag=True; engine._red_reason=("high_PE" if PE>self.pe_hi else ("low_Psi" if Psi<self.psi_lo else "high_H"))
            engine.params.lambda_=-0.9
            if hasattr(engine.backend,"noise"): engine.backend.noise=engine._noise_default+0.06
            if hasattr(engine,"wm"): engine.wm.items=[]; engine.wm.scores=[]
            if hasattr(engine,"ret"): engine.ret.buf.clear()
            self.cooldowns[eid]=6
            tid=hashlib.sha256(f"task|{eid}|{k}|{Psi:.6f}|{PE:.6f}|{H:.6f}".encode("utf-8")).hexdigest()
            self.collector.add({"id":tid,"engine":int(engine_idx or 0),"k":int(k),"t":float(stats["t"]),"type":"counterfactual_rehearsal",
                               "directives":["collect exemplars around spike","increase rollout horizon and ensemble","stabilize via high-C/high-Φ anchor retrieval"],
                               "params":{"N":16,"H":3.0},"reason":engine._red_reason,"Psi":float(Psi),"PE":float(PE),"H":float(H)})
            self.cf_until[eid]=k+6
        rem=self.cooldowns.get(eid,0)
        if rem>0: self.cooldowns[eid]=rem-1
        else:
            if Psi>=self.psi_recover:
                engine.params.lambda_=engine._lambda_default
                if hasattr(engine.backend,"noise"): engine.backend.noise=engine._noise_default

def regimen(k, phases):
    for (name,k0,k1,p) in phases:
        if k0<=k<=k1: return name,p
    return "default", {}

def run_vigil_plus(num_agents=50, steps=80, seed=13579, out_dir="./vigil_pp_outputs"):
    os.makedirs(out_dir, exist_ok=True)
    phases=[("Prelude",1,20,{"shock_prob":0.10,"drift":0.02,"burst_len":5}),
            ("VoidSurge",21,40,{"shock_prob":0.35,"drift":0.03,"burst_len":10,"desync":0.20}),
            ("Breach",41,60,{"shock_prob":0.50,"drift":0.035,"burst_len":12,"desync":0.30}),
            ("Reprieve",61,70,{"shock_prob":0.08,"drift":0.02,"burst_len":4}),
            ("Aftershocks",71,80,{"shock_prob":"alt(0.40,0.12,5)","drift":0.03,"burst_len":8})]
    collectors=[TaskCollector() for _ in range(num_agents)]
    guardians=[VoidGuardianPP(collectors[i]) for i in range(num_agents)]
    envs=[AdversarialEnv(input_dim=16, shock_prob=0.10, drift=0.02, burst_len=5, seed=seed+i) for i in range(num_agents)]
    params=[Params(dt=0.2, W_r=3.0, H=2.0, N=8, C_w=32, latent_dim=32) for _ in range(num_agents)]
    backends=[SimpleBackend(input_dim=16, latent_dim=32, seed=seed+i) for i in range(num_agents)]
    agents=[PsiEngine(backends[i], params[i]) for i in range(num_agents)]
    per_agent=[[] for _ in range(num_agents)]; swarm_rows=[]
    def alt(val_str,k): a,b,per = val_str.strip()[4:-1].split(","); a=float(a); b=float(b); per=int(per); return a if ((k//per)%2==0) else b
    for k in range(1, steps+1):
        phase,ov = regimen(k, phases)
        desync=float(ov.get("desync",0.0))
        for env in envs:
            shock=ov.get("shock_prob", env.shock_prob)
            if isinstance(shock,str) and shock.startswith("alt("): shock = alt(shock, k)
            env.shock_prob=float(shock); env.drift=float(ov.get("drift", env.drift)); env.burst_len=int(ov.get("burst_len", env.burst_len))
        psi_vals=[]; pe_vals=[]; h_vals=[]
        for i,eng in enumerate(agents):
            if desync>0.0 and np.random.rand()<desync:
                if hasattr(eng,"ret"): eng.ret.buf.clear()
                if hasattr(eng,"wm"): eng.wm.items=[]; eng.wm.scores=[]
            x=envs[i].step(); G=guardians[i]
            def g_out(stats, engine, _i=i): G.outbound(stats, engine, engine_idx=_i)
            rec=eng.step(x, guardian_in=G.inbound, guardian_out=g_out)
            per_agent[i].append({**rec, "agent": i, "phase": phase})
            psi_vals.append(rec["Psi"]); pe_vals.append(rec["PE"]); h_vals.append(rec["H"])
        swarm_rows.append({"k":k,"phase":phase,"Psi_swarm":float(np.mean(psi_vals)),
                           "Avg_Psi_agents":float(np.mean(psi_vals)),"PE_swarm":float(np.mean(pe_vals)),
                           "H_swarm":float(np.mean(h_vals)),"RedFlags":0})
    # Save per-agent telemetry
    for i,rows in enumerate(per_agent): pd.DataFrame(rows).to_csv(os.path.join(out_dir, f"telemetry_agent_{i}.csv"), index=False)
    swarm_df=pd.DataFrame(swarm_rows); swarm_csv=os.path.join(out_dir,"swarm_summary.csv"); swarm_df.to_csv(swarm_csv, index=False)
    # Merge ledgers + tasks
    L_ret=[]; L_epi=[]; L_proto=[]
    for eng in agents: L_ret.extend(eng.ledgers.L_ret); L_epi.extend(eng.ledgers.L_epi); L_proto.extend(eng.ledgers.L_proto)
    tasks_path=os.path.join(out_dir,"L_task.jsonl"); merged=TaskCollector()
    for C in collectors: [merged.add(t) for t in C.tasks]
    merged.write(tasks_path)
    red_ret=sum(1 for a in L_ret if a.get("meta",{}).get("red_flag")); red_epi=sum(1 for a in L_epi if a.get("meta",{}).get("red_flag"))
    with open(os.path.join(out_dir,"swarm_ledgers_merged.json"),"w",encoding="utf-8") as f:
        json.dump({"L_ret":L_ret,"L_epi":L_epi,"L_proto":L_proto,
                   "red_flags":{"L_ret":red_ret,"L_epi":red_epi,"L_task":len(merged.tasks)}}, f, indent=2)
    # Compute RedFlags column from tasks (engine k is 0-based)
    counts={}
    with open(tasks_path,"r",encoding="utf-8") as f:
        for line in f:
            t=json.loads(line); kg=int(t["k"])+1; counts[kg]=counts.get(kg,0)+1
    swarm_df["RedFlags"]=swarm_df["k"].map(lambda kk: counts.get(int(kk),0)).astype(int)
    swarm_df.to_csv(swarm_csv, index=False)
    # Charts
    charts_dir=os.path.join(out_dir,"charts"); os.makedirs(charts_dir, exist_ok=True)
    fig=plt.figure(); plt.plot(swarm_df["k"],swarm_df["Psi_swarm"]); plt.xlabel("cycle k"); plt.ylabel("Psi_swarm"); plt.title("Psi_swarm (Eternal Vigil++)")
    plt.savefig(os.path.join(charts_dir,"Psi_swarm.png"),dpi=150,bbox_inches="tight"); plt.close(fig)
    fig=plt.figure(); plt.plot(swarm_df["k"],swarm_df["PE_swarm"]); plt.xlabel("cycle k"); plt.ylabel("PE_swarm"); plt.title("PE_swarm (Eternal Vigil++)")
    plt.savefig(os.path.join(charts_dir,"PE_swarm.png"),dpi=150,bbox_inches="tight"); plt.close(fig)
    fig=plt.figure(); plt.plot(swarm_df["k"],swarm_df["H_swarm"]); plt.xlabel("cycle k"); plt.ylabel("H_swarm"); plt.title("H_swarm (Eternal Vigil++)")
    plt.savefig(os.path.join(charts_dir,"H_swarm.png"),dpi=150,bbox_inches="tight"); plt.close(fig)
    fig=plt.figure(); plt.plot(swarm_df["k"],swarm_df["RedFlags"]); plt.xlabel("cycle k"); plt.ylabel("RedFlags"); plt.title("Red-flag Tasks per Cycle")
    plt.savefig(os.path.join(charts_dir,"RedFlags.png"),dpi=150,bbox_inches="tight"); plt.close(fig)
    # Compute dt_eff extrema
    dt_mins=[]; dt_maxs=[]; pe_maxs=[]; h_maxs=[]
    for i in range(num_agents):
        df=pd.read_csv(os.path.join(out_dir,f"telemetry_agent_{i}.csv"))
        dt_mins.append(df["dt_eff"].min()); dt_maxs.append(df["dt_eff"].max()); pe_maxs.append(df["PE"].max()); h_maxs.append(df["H"].max())
    # Collapse/recovery
    collapses=swarm_df.index[swarm_df["Psi_swarm"]<0.30].tolist(); recs=[]
    for idx in collapses:
        kc=int(swarm_df.loc[idx,"k"]); rec=swarm_df.loc[idx:]; hit=rec[rec["Psi_swarm"]>=0.85].head(1)
        if not hit.empty: kr=int(hit["k"].iloc[0]); recs.append({"collapse_k":kc,"recovery_k":kr,"cycles_to_recover":kr-kc})
    mani={"swarm_summary_csv":swarm_csv,"charts":{"Psi_swarm":os.path.join(charts_dir,"Psi_swarm.png"),
         "PE_swarm":os.path.join(charts_dir,"PE_swarm.png"),"H_swarm":os.path.join(charts_dir,"H_swarm.png"),
         "RedFlags":os.path.join(charts_dir,"RedFlags.png")},
         "ledgers_merged":os.path.join(out_dir,"swarm_ledgers_merged.json"),"tasks_ledger":tasks_path,
         "agents":num_agents,"steps":steps,
         "Psi0":float(swarm_df["Psi_swarm"].iloc[0]),"PsiF":float(swarm_df["Psi_swarm"].iloc[-1]),
         "DeltaPsi":float(swarm_df["Psi_swarm"].iloc[-1]-swarm_df["Psi_swarm"].iloc[0]),
         "collapse_events":recs,
         "dt_eff_min_observed":float(np.min(dt_mins)),"dt_eff_max_observed":float(np.max(dt_maxs)),
         "PE_max_observed":float(np.max(pe_maxs)),"H_max_observed":float(np.max(h_maxs)),
         "red_flag_counts":{"L_ret":red_ret,"L_epi":red_epi,"L_task":len(merged.tasks)}}
    with open(os.path.join(out_dir,"manifest.json"),"w",encoding="utf-8") as f: json.dump(mani,f,indent=2)
    return mani, swarm_df

def main():
    ap=argparse.ArgumentParser(description="Eternal Vigil++ runner")
    ap.add_argument("--agents",type=int,default=50)
    ap.add_argument("--steps",type=int,default=80)
    ap.add_argument("--seed", type=int,default=13579)
    ap.add_argument("--out",  type=str, default="./vigil_pp_outputs")
    args=ap.parse_args()
    mani,_=run_vigil_plus(num_agents=args.agents, steps=args.steps, seed=args.seed, out_dir=args.out)
    print(json.dumps(mani, indent=2))

if __name__=="__main__":
    main()
