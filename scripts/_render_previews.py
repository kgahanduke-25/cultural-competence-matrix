"""
_render_previews.py  (helper, not part of the R pipeline)

Renders PNG previews of the four figures so the README displays them without a
local R install. The canonical generator is scripts/generate_figures.R; this
script reproduces the same specification from the same CSV data for previewing.
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
from math import pi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
FIG = os.path.join(ROOT, "figures")
os.makedirs(FIG, exist_ok=True)

meta = pd.read_csv(os.path.join(DATA, "domains_metadata.csv"))
mat = pd.read_csv(os.path.join(DATA, "example_matrix.csv"))
plur = pd.read_csv(os.path.join(DATA, "pluralism_transition.csv"))

mat = mat.merge(meta, on="domain_id")
DOMAIN_ORDER = list(meta["domain_id"])
SHORT = dict(zip(meta["domain_id"], meta["short_label"]))
POPS = list(dict.fromkeys(mat["population"]))

CASE = "Malayali (Sitheri Hills)"
CAPTION = ("Cultural Competence Matrix | ordinal 0-3 (0 = absent, 3 = strong). "
           "Malayali = documented dissertation case; others illustrative/synthetic.")
CAT = ["#1b4965", "#e07a5f", "#3d8c5f", "#8367c7", "#c08552", "#5fa8d3"]

plt.rcParams.update({
    "font.family": "DejaVu Sans", "axes.edgecolor": "#cccccc",
    "axes.titleweight": "bold", "figure.dpi": 200,
})


def caption(ax, text):
    ax.figure.text(0.01, 0.005, text, ha="left", va="bottom",
                   fontsize=7, color="#6b6b6b")


# ---------------------------------------------------------------- Figure 1
def fig_heatmap():
    grid = (mat.pivot(index="domain_id", columns="population", values="score")
            .reindex(index=DOMAIN_ORDER, columns=POPS))
    fig, ax = plt.subplots(figsize=(10, 6))
    norm = TwoSlopeNorm(vmin=0, vcenter=1.5, vmax=3)
    cmap = plt.get_cmap("RdBu")
    im = ax.imshow(grid.values, cmap=cmap, norm=norm, aspect="auto")
    for i in range(grid.shape[0]):
        for j in range(grid.shape[1]):
            ax.text(j, i, int(grid.values[i, j]), ha="center", va="center",
                    color="#1a1a1a", fontweight="bold", fontsize=11)
    ax.set_xticks(range(len(POPS)))
    ax.set_xticklabels(POPS, rotation=18, ha="left", fontsize=8.5, fontweight="bold")
    ax.xaxis.set_ticks_position("top")
    ax.set_yticks(range(len(DOMAIN_ORDER)))
    ax.set_yticklabels([SHORT[d] for d in DOMAIN_ORDER], fontsize=9)
    for sp in ax.spines.values():
        sp.set_visible(False)
    ax.set_xticks(np.arange(-.5, len(POPS), 1), minor=True)
    ax.set_yticks(np.arange(-.5, len(DOMAIN_ORDER), 1), minor=True)
    ax.grid(which="minor", color="white", linewidth=2.5)
    ax.tick_params(which="both", length=0)
    cb = fig.colorbar(im, ax=ax, ticks=[0, 1, 2, 3], shrink=0.7, pad=0.02)
    cb.set_label("Score", fontweight="bold")
    fig.text(0.02, 0.965, "Cultural Competence Matrix: access scored across six domains",
             fontsize=15, fontweight="bold", color="#1a1a1a")
    fig.text(0.02, 0.925, "Each cell is an ordinal 0-3 score; columns are populations, rows are domains",
             fontsize=10, color="#555")
    caption(ax, CAPTION)
    fig.subplots_adjust(top=0.74, bottom=0.06, left=0.20, right=0.98)
    fig.savefig(os.path.join(FIG, "01_matrix_heatmap.png"))
    plt.close(fig)


# ---------------------------------------------------------------- Figure 2
def fig_radar():
    pops = [CASE, "Remote Indigenous community"]
    labels = [SHORT[d] for d in DOMAIN_ORDER]
    N = len(labels)
    angles = [n / float(N) * 2 * pi for n in range(N)] + [0]
    fig, ax = plt.subplots(figsize=(8.5, 7.5), subplot_kw=dict(polar=True))
    for k, pop in enumerate(pops):
        row = mat[mat["population"] == pop].set_index("domain_id").reindex(DOMAIN_ORDER)
        vals = list(row["score"]) + [row["score"].iloc[0]]
        ax.plot(angles, vals, color=CAT[k], linewidth=2, label=pop)
        ax.fill(angles, vals, color=CAT[k], alpha=0.18)
        ax.scatter(angles, vals, color=CAT[k], s=28, zorder=5)
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylim(0, 3)
    ax.set_yticks([0, 1, 2, 3])
    ax.set_yticklabels(["0", "1", "2", "3"], color="#777", fontsize=8)
    ax.set_title("Access profiles: documented case vs. an illustrative contrast",
                 fontsize=14, pad=26, loc="center")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.06), frameon=False, fontsize=9)
    caption(ax, CAPTION)
    fig.subplots_adjust(top=0.85, bottom=0.14)
    fig.savefig(os.path.join(FIG, "02_radar_profiles.png"))
    plt.close(fig)


# --------------------------------------------------- indices (shared by fig 3)
def compute_indices():
    cap_dom = {"D1", "D2", "D3"}
    rows = []
    for pop in POPS:
        sub = mat[mat["population"] == pop]
        comp = sub["score"].mean() / 3 * 100
        cap = sub[sub["domain_id"].isin(cap_dom)]["score"].mean() / 3 * 100
        real = sub[~sub["domain_id"].isin(cap_dom)]["score"].mean() / 3 * 100
        rows.append((pop, comp, cap, real, cap - real))
    df = pd.DataFrame(rows, columns=["population", "composite", "capacity",
                                     "realized", "gap"])
    return df.sort_values("composite").reset_index(drop=True)


# ---------------------------------------------------------------- Figure 3
def fig_gap():
    df = compute_indices()
    fig, ax = plt.subplots(figsize=(9.5, 6))
    y = range(len(df))
    ax.hlines(y, df["realized"], df["capacity"], color="#bfbfbf", linewidth=4, zorder=1)
    ax.scatter(df["capacity"], y, color="#2166ac", s=90, zorder=3, label="Capacity (provision)")
    ax.scatter(df["realized"], y, color="#e07a5f", s=90, zorder=3, label="Realized (dignified use)")
    for i, r in df.iterrows():
        ax.text(max(r["capacity"], r["realized"]) + 3, i, f"gap {r['gap']:+.0f}",
                va="center", fontsize=9, color="#555")
    ax.set_yticks(list(y))
    ax.set_yticklabels(df["population"], fontsize=9)
    ax.set_xlim(0, 108)
    ax.set_xlabel("Access index (0-100)")
    fig.text(0.02, 0.95, "The conversion gap: does built capacity become dignified use?",
             fontsize=13, fontweight="bold", color="#1a1a1a")
    fig.text(0.02, 0.905, "Distance between dots = access the system provides but does not realize (Andersen)",
             fontsize=10, color="#555")
    ax.legend(loc="lower right", frameon=False, fontsize=9)
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="x", color="#ececec")
    caption(ax, CAPTION)
    fig.subplots_adjust(top=0.86, left=0.30, right=0.97, bottom=0.12)
    fig.savefig(os.path.join(FIG, "03_conversion_gap.png"))
    plt.close(fig)


# ---------------------------------------------------------------- Figure 4
def fig_pluralism():
    order = ["Traditional medicine (Ta-ta)", "Primary Health Centre (PHC)",
             "Community Health Centre (CHC)"]
    colors = {"Traditional medicine (Ta-ta)": "#3d8c5f",
              "Primary Health Centre (PHC)": "#1b4965",
              "Community Health Centre (CHC)": "#e07a5f"}
    periods = list(dict.fromkeys(plur.sort_values("period_order")["period"]))
    fig, ax = plt.subplots(figsize=(8.5, 6))
    for sysname in order:
        sub = plur[plur["system"] == sysname].sort_values("period_order")
        ax.plot([0, 1], sub["reliance"], color=colors[sysname], linewidth=2.4,
                marker="o", markersize=8, label=sysname)
        last = sub.iloc[-1]["reliance"]
        ax.text(1.03, last, f"{last*100:.0f}%", va="center", fontsize=10,
                color=colors[sysname])
    ax.set_xticks([0, 1])
    ax.set_xticklabels(periods)
    ax.set_xlim(-0.1, 1.35)
    ax.set_ylim(0, 0.8)
    ax.set_yticks(np.arange(0, 0.81, 0.2))
    ax.set_yticklabels([f"{int(v*100)}%" for v in np.arange(0, 0.81, 0.2)])
    ax.set_ylabel("Share of care-seeking (illustrative)")
    ax.set_title("Medical pluralism in transition (Sitheri Hills)", fontsize=14, loc="left")
    fig.text(0.09, 0.90, "Schematic of the dissertation's directional finding: ethnomedicine contracts as the PHC embeds",
             fontsize=10, color="#555")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.08), frameon=False,
              fontsize=9, ncol=1)
    ax.spines[["top", "right"]].set_visible(False)
    caption(ax, "Schematic of a qualitative directional finding, not measured percentages.")
    fig.subplots_adjust(top=0.84, bottom=0.22, left=0.10, right=0.97)
    fig.savefig(os.path.join(FIG, "04_pluralism_transition.png"))
    plt.close(fig)


if __name__ == "__main__":
    fig_heatmap()
    fig_radar()
    fig_gap()
    fig_pluralism()
    idx = compute_indices().sort_values("composite", ascending=False)
    print(idx.to_string(index=False))
    print("Rendered 4 preview figures to figures/.")
