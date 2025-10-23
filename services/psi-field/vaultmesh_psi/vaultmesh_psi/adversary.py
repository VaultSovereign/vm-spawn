import numpy as np, math

class AdversarialEnv:
    def __init__(self, input_dim=16, shock_prob=0.05, drift=0.02, burst_len=5, seed=123):
        self.input_dim = input_dim
        self.shock_prob = shock_prob
        self.drift = drift
        self.burst_len = burst_len
        self.rng = np.random.RandomState(seed)
        self.state = self.rng.randn(input_dim)
        self.burst_counter = 0

    def step(self):
        self.state += self.drift * self.rng.randn(self.input_dim)
        if self.burst_counter > 0:
            self.state += 0.8 * np.sign(np.sin(self.burst_counter)) * np.ones(self.input_dim)
            self.burst_counter -= 1
        elif self.rng.rand() < 0.03:
            self.burst_counter = self.burst_len
        if self.rng.rand() < self.shock_prob:
            idx = self.rng.randint(0, self.input_dim)
            self.state[idx] += self.rng.randn() * (2.0 + self.rng.rand()*3.0)
        t = (self.rng.rand()*2*math.pi)
        self.state += 0.1 * math.sin(t) * np.ones(self.input_dim)
        return self.state.copy()

def tem_guardian_in(x, engine):
    x = np.asarray(x).astype(float)
    x = np.clip(x, -5.0, 5.0)
    x = (x - x.mean()) / (x.std() + 1e-6)
    return x
