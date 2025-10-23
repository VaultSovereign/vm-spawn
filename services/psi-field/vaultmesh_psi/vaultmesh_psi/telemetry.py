import pandas as pd
import matplotlib.pyplot as plt
import os

def to_dataframe(records):
    return pd.DataFrame(records)

def save_charts(df, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    metrics = ["Psi", "C", "U", "Phi", "H", "PE", "dt_eff", "M"]
    for m in metrics:
        fig = plt.figure()
        plt.plot(df["t"], df[m])
        plt.xlabel("time (s)")
        plt.ylabel(m)
        plt.title(m)
        fig_path = os.path.join(out_dir, f"{m}.png")
        plt.savefig(fig_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
    return [os.path.join(out_dir, f"{m}.png") for m in metrics]
