import numpy as np
from collections import deque
import hashlib, time, json, random

EPS = 1e-8

def cos_sim(a, b):
    a = np.asarray(a).reshape(-1)
    b = np.asarray(b).reshape(-1)
    na = np.linalg.norm(a) + 1e-12
    nb = np.linalg.norm(b) + 1e-12
    return float(np.dot(a, b) / (na * nb))

def entropy_hist(arr, bins=32):
    x = np.asarray(arr).reshape(-1)
    if x.size == 0:
        return 0.0
    x = (x - x.mean()) / (x.std() + EPS)
    hist, _ = np.histogram(x, bins=bins, density=True)
    p = hist / (hist.sum() + EPS)
    p = p[p > 0]
    return float(-np.sum(p * np.log(p + EPS)))

def pseudo_phase(v):
    v = np.asarray(v).reshape(-1)
    m = v.mean()
    s = v.std() + EPS
    return float(np.arctan2(m, s))

def phase_coherence(vectors):
    if len(vectors) == 0:
        return 0.0
    phases = [pseudo_phase(v) for v in vectors]
    re = np.mean([np.cos(p) for p in phases])
    im = np.mean([np.sin(p) for p in phases])
    return float(np.sqrt(re*re + im*im))

def clamp(x, lo, hi):
    return max(lo, min(hi, x))

def softmax(x, temp=1.0):
    x = np.asarray(x, dtype=float)
    x = x / max(temp, EPS)
    x = x - x.max()
    ex = np.exp(x)
    return ex / (ex.sum() + EPS)

def hash_trace(vec, meta=None):
    h = hashlib.sha256()
    h.update(np.asarray(vec).astype(np.float32).tobytes())
    if meta is not None:
        h.update(json.dumps(meta, sort_keys=True).encode("utf-8"))
    return h.hexdigest()

class RetentionBuffer:
    def __init__(self, max_seconds, dt, latent_dim):
        self.max_len = int(max(1, round(max_seconds / dt)))
        self.buf = deque(maxlen=self.max_len)
        self.latent_dim = latent_dim

    def push(self, z):
        self.buf.append(np.asarray(z))

    def summary(self):
        if len(self.buf) == 0:
            return np.zeros(self.latent_dim, dtype=float)
        return np.mean(np.stack(self.buf, axis=0), axis=0)

    @property
    def traces(self):
        return list(self.buf)

class EpisodicMemory:
    def __init__(self, latent_dim, capacity=4096):
        self.latent_dim = latent_dim
        self.capacity = capacity
        self.vectors = []
        self.meta = []

    def add(self, vec, meta=None):
        if len(self.vectors) >= self.capacity:
            drop = max(1, self.capacity // 10)
            self.vectors = self.vectors[drop:]
            self.meta = self.meta[drop:]
        self.vectors.append(np.asarray(vec))
        self.meta.append(meta or {})

    def attend(self, q, topk=8):
        if len(self.vectors) == 0:
            return np.zeros_like(q), 0.0
        sims = np.array([cos_sim(q, v) for v in self.vectors])
        idxs = np.argsort(sims)[-topk:]
        if idxs.size == 0:
            return np.zeros_like(q), 0.0
        weights = softmax(sims[idxs])
        ctx = np.sum([self.vectors[i] * weights[j] for j, i in enumerate(idxs)], axis=0)
        quality = float(np.mean(sims[idxs]))
        return ctx, quality

class WorkingMemory:
    def __init__(self, capacity):
        self.capacity = capacity
        self.items = []
        self.scores = []

    def add(self, vec, score):
        self.items.append(np.asarray(vec))
        self.scores.append(float(score))
        if len(self.items) > self.capacity:
            idxs = np.argsort(self.scores)[-self.capacity:]
            self.items = [self.items[i] for i in idxs]
            self.scores = [self.scores[i] for i in idxs]

    def usage(self):
        return min(1.0, len(self.items) / float(self.capacity))

class Ledgers:
    def __init__(self):
        self.L_ret = []
        self.L_epi = []
        self.L_proto = []

    def append_ret(self, anchor):
        self.L_ret.append(anchor)

    def append_epi(self, anchor):
        self.L_epi.append(anchor)

    def append_proto(self, anchor):
        self.L_proto.append(anchor)

class Params:
    def __init__(self,
                 dt=0.2, W_r=3.0, H=2.0, N=8, C_w=32, latent_dim=32,
                 w=(1.0,0.8,0.6,0.6,0.7,0.7),
                 alpha=1.0, beta=1.0,
                 lambda_=0.6, dt_min=0.05, dt_max=0.5,
                 eps=1e-6,
                 g0=1.0, g1=0.5, g2=0.2,
                 consolidate_thresholds=(0.6, 0.4, (0.1, 1.5)),
                 rollout_dt_fraction=1.0):
        self.dt = float(dt)
        self.W_r = float(W_r)
        self.H = float(H)
        self.N = int(N)
        self.C_w = int(C_w)
        self.latent_dim = int(latent_dim)
        self.w1, self.w2, self.w3, self.w4, self.w5, self.w6 = w
        self.alpha = float(alpha)
        self.beta = float(beta)
        self.lambda_ = float(lambda_)
        self.dt_min = float(dt_min)
        self.dt_max = float(dt_max)
        self.eps = float(eps)
        self.g0, self.g1, self.g2 = g0, g1, g2
        self.tau_psi, self.tau_c, self.tau_pe_range = consolidate_thresholds
        self.rollout_dt_fraction = float(rollout_dt_fraction)

class PsiEngine:
    def __init__(self, backend, params: Params):
        self.backend = backend
        self.params = params
        self.ret = RetentionBuffer(params.W_r, params.dt, params.latent_dim)
        self.em = EpisodicMemory(params.latent_dim)
        self.wm = WorkingMemory(params.C_w)
        self.ledgers = Ledgers()
        self.theta = backend.init_theta(params.latent_dim)
        self.prev_P = None
        self.prev_z_hat = None
        self.k = 0
        self.time_s = 0.0

    def consolidate_gate(self, Psi, PE, C):
        lo, hi = self.params.tau_pe_range
        return (Psi > self.params.tau_psi and C > self.params.tau_c) or (lo <= PE <= hi)

    def step(self, x_k, guardian_in=None, guardian_out=None):
        p = self.params
        if callable(guardian_in):
            x_k = guardian_in(x_k, self)

        z = self.backend.encode(x_k)
        P_k = z

        if self.prev_P is not None:
            self.ret.push(self.prev_P)

        if self.prev_P is not None:
            z_hat_from_prev = self.backend.predict(self.prev_P, self.theta, self.em)
        else:
            z_hat_from_prev = np.copy(P_k)

        rollouts = self.backend.rollout(self.theta, P_k, horizon=p.H, N=p.N, dt=p.dt * p.rollout_dt_fraction)

        phi = P_k + 0.5*self.ret.summary()
        ctx, q = self.em.attend(P_k, topk=8)

        M_k = p.alpha * self.wm.usage() + p.beta * max(0.0, q)

        C_k = cos_sim(phi, ctx) if np.linalg.norm(ctx) > 0 else 0.0

        if len(rollouts) > 0:
            first_steps = [traj[0] for traj in rollouts if len(traj) > 0]
            U_k = float(np.mean([cos_sim(P_k, fs) for fs in first_steps])) if len(first_steps) > 0 else 0.0
        else:
            U_k = 0.0

        rollout_snaps = []
        for traj in rollouts:
            if len(traj) > 0:
                rollout_snaps.append(traj[0])
        vectors_for_phase = [phi] + self.ret.traces + rollout_snaps
        Phi_k = phase_coherence(vectors_for_phase)

        H_k = entropy_hist(np.concatenate([P_k, ctx, phi]))

        PE_k = float(np.linalg.norm(P_k - z_hat_from_prev))

        rho_k = p.dt / (p.eps + M_k)
        x_val = p.w1*(1.0/rho_k) + p.w2*C_k + p.w3*U_k + p.w4*Phi_k - p.w5*H_k - p.w6*PE_k
        Psi_k = float(1.0 / (1.0 + np.exp(-x_val)))

        att_gain = p.g0 + p.g1*Psi_k - p.g2*PE_k
        dt_eff = clamp(p.dt * (1.0 + p.lambda_*(1.0 - Psi_k)), p.dt_min, p.dt_max)

        sal = max(0.0, Psi_k - 0.5*PE_k)
        self.wm.add(phi, score=sal)

        if self.consolidate_gate(Psi_k, PE_k, C_k):
            meta = dict(t=self.time_s, Psi=Psi_k, k=self.k)
            self.em.add(phi, meta=meta)
            anchor = dict(hash=hash_trace(phi, meta), meta=meta)
            self.ledgers.append_ret(anchor)
            if sal > 0.0 and random.random() < 0.3:
                self.ledgers.append_epi(anchor)

        if self.prev_P is not None:
            self.theta = self.backend.update_theta(self.theta, self.prev_P, P_k)

        proto_meta = dict(t=self.time_s, k=self.k, U=U_k)
        proto_hash = hashlib.sha256((str(P_k[:4]) + str(U_k)).encode("utf-8")).hexdigest()
        self.ledgers.append_proto(dict(hash=proto_hash, meta=proto_meta))

        if callable(guardian_out):
            guardian_out(dict(Psi=Psi_k, PE=PE_k, C=C_k, U=U_k, Phi=Phi_k, t=self.time_s, k=self.k), self)

        self.prev_P = P_k
        self.prev_z_hat = z_hat_from_prev
        self.k += 1
        self.time_s += dt_eff

        rec = dict(k=self.k, t=self.time_s, Psi=Psi_k, C=C_k, U=U_k, Phi=Phi_k, H=H_k, PE=PE_k, dt_eff=dt_eff, M=M_k, att_gain=att_gain)
        return rec

class SyntheticEnv:
    def __init__(self, input_dim=16, change_prob=0.02, drift=0.02, seed=42):
        self.input_dim = input_dim
        self.change_prob = change_prob
        self.drift = drift
        self.rng = np.random.RandomState(seed)
        self.state = self.rng.randn(input_dim)

    def step(self):
        self.state += self.drift * self.rng.randn(self.input_dim)
        if self.rng.rand() < self.change_prob:
            self.state = self.rng.randn(self.input_dim) * (1.0 + 0.5*self.rng.rand())
        t = time.time() % (2*np.pi)
        self.state += 0.1 * np.sin(t) * np.ones(self.input_dim)
        return self.state.copy()
