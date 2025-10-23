import numpy as np

class SimpleBackend:
    def __init__(self, input_dim=16, latent_dim=32, seed=7, eta=0.05, noise=0.02):
        self.input_dim = input_dim
        self.latent_dim = latent_dim
        self.rng = np.random.RandomState(seed)
        self.E = 0.5 * self.rng.randn(latent_dim, input_dim)
        self.A = np.eye(latent_dim) + 0.05 * self.rng.randn(latent_dim, latent_dim)
        self.eta = eta
        self.noise = noise

    def init_theta(self, latent_dim):
        return dict(A=self.A.copy())

    def encode(self, x):
        z_lin = self.E @ np.asarray(x).reshape(-1)
        return np.tanh(z_lin)

    def predict(self, z, theta, EM=None):
        A = theta["A"]
        return A @ z

    def rollout(self, theta, start, horizon=2.0, N=8, dt=0.2):
        steps = max(1, int(round(horizon / dt)))
        A = theta["A"]
        res = []
        for _ in range(N):
            z = start.copy()
            traj = []
            for _ in range(steps):
                z = A @ z + self.noise * self.rng.randn(*z.shape)
                traj.append(z.copy())
            res.append(traj)
        return res

    def update_theta(self, theta, z_prev, z_curr):
        A = theta["A"]
        z_hat = A @ z_prev
        err = (z_hat - z_curr).reshape(-1, 1)
        denom = float(np.dot(z_prev, z_prev) + 1e-6)
        grad = (err @ z_prev.reshape(1, -1)) / denom
        A_new = A - self.eta * grad
        theta["A"] = A_new
        return theta
