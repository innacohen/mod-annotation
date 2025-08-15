
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

def plot_subtype_sensitivity_dumbbell(df_both,
                                      true_col="true_subtype",
                                      gpt_col="gpt_pred_subtype",
                                      xgb_col="xgb_pred_subtype",
                                      min_n=3,          # hide very rare subtypes
                                      top_n=None,       # or keep only top N by |gap|
                                      show_legend=True,
                                      figsize=(10, 9)):
    df = df_both[[true_col, gpt_col, xgb_col]].dropna(subset=[true_col]).copy()
    subtypes = sorted(df[true_col].unique())

    rows = []
    for st in subtypes:
        total = (df[true_col] == st).sum()
        if total == 0: 
            continue
        tp_xgb = ((df[true_col] == st) & (df[xgb_col] == st)).sum()
        tp_gpt = ((df[true_col] == st) & (df[gpt_col] == st)).sum()
        sens_xgb = tp_xgb / total
        sens_gpt = tp_gpt / total
        rows.append({
            "subtype": st, "n": total,
            "sens_xgb": sens_xgb * 100,
            "sens_gpt": sens_gpt * 100,
            "gap": (sens_xgb - sens_gpt) * 100
        })
    res = pd.DataFrame(rows)

    # filter very small n
    res = res[res["n"] >= min_n].copy()

    # order by absolute gap (biggest story first)
    res["abs_gap"] = res["gap"].abs()
    res = res.sort_values(["abs_gap", "n"], ascending=[False, False])

    if top_n:
        res = res.head(top_n)

    y = np.arange(len(res))

    fig, ax = plt.subplots(figsize=figsize)

    # dumbbell: line between the two model points
    for i, r in res.reset_index(drop=True).iterrows():
        x1, x2 = r["sens_gpt"], r["sens_xgb"]
        ax.plot([min(x1, x2), max(x1, x2)], [i, i], lw=2, color="lightgray", zorder=1)

    # dots
    ax.scatter(res["sens_gpt"], y, label="GPT", s=40, color="lightgray", edgecolor="gray", zorder=2)
    ax.scatter(res["sens_xgb"], y, label="XGB", s=40, color="dimgray", zorder=3)

    # subtype labels on y; n at right
    ax.set_yticks(y)
    ax.set_yticklabels(res["subtype"])
    for i, r in res.reset_index(drop=True).iterrows():
        ax.text(101.5, i, f"n={int(r['n'])}", va="center", ha="left", fontsize=9, color="dimgray")

    # cosmetics
    ax.set_xlim(0, 110)  # leave space for n labels
    ax.set_xlabel("Sensitivity (True Positive %)")
    ax.set_title("Subtype Sensitivity (Recall): GPT vs XGB (ranked by |gap|)")
    ax.grid(axis="x", linestyle=":", alpha=0.4)
    if show_legend:
        ax.legend(loc="center left", bbox_to_anchor=(1.02, 0.5), frameon=False)

    plt.tight_layout()
    plt.show()

# Example:
plot_subtype_sensitivity_dumbbell(df_both, min_n=3, top_n=12)




# V2

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

def plot_subtype_sensitivity_dumbbell(df_both,
                                      true_col="true_subtype",
                                      gpt_col="gpt_pred_subtype",
                                      xgb_col="xgb_pred_subtype",
                                      min_n=3,        # hide very rare subtypes
                                      top_n=None,     # keep top N by |gap|
                                      show_legend=True,
                                      annotate_gap=True,
                                      figsize=(10, 9)):
    df = df_both[[true_col, gpt_col, xgb_col]].dropna(subset=[true_col]).copy()

    rows = []
    for st, grp in df.groupby(true_col):
        total = len(grp)
        tp_xgb = (grp[xgb_col] == st).sum()
        tp_gpt = (grp[gpt_col] == st).sum()
        sens_xgb = 100 * tp_xgb / total
        sens_gpt = 100 * tp_gpt / total
        rows.append({
            "subtype": st, "n": total,
            "sens_xgb": sens_xgb, "sens_gpt": sens_gpt,
            "gap": sens_xgb - sens_gpt  # >0 => XGB wins
        })
    res = pd.DataFrame(rows)

    # filter & order
    res = res[res["n"] >= min_n].copy()
    res["abs_gap"] = res["gap"].abs()
    res = res.sort_values(["abs_gap", "n"], ascending=[False, False])
    if top_n: res = res.head(top_n)

    y = np.arange(len(res))
    fig, ax = plt.subplots(figsize=figsize)

    # draw winner-colored lines first
    for i, r in res.reset_index(drop=True).iterrows():
        x1, x2 = r["sens_gpt"], r["sens_xgb"]
        x_lo, x_hi = (x1, x2) if x1 <= x2 else (x2, x1)
        winner_color = "dimgray" if r["gap"] > 0 else "lightgray"  # dark=XGB, light=GPT
        ax.plot([x_lo, x_hi], [i, i], lw=4, color=winner_color, alpha=0.9, solid_capstyle="round")

        if annotate_gap and r["abs_gap"] >= 3:  # annotate only meaningful gaps
            x_mid = (x_lo + x_hi) / 2
            txt = f"{r['gap']:+.1f}%"
            ax.text(x_mid, i + 0.15, txt, ha="center", va="bottom", fontsize=9, color=winner_color)

    # dots
    ax.scatter(res["sens_gpt"], y, label="GPT", s=40, color="white", edgecolor="gray", zorder=3)
    ax.scatter(res["sens_xgb"], y, label="XGB", s=40, color="dimgray", zorder=3)

    # y labels and n labels on the right
    ax.set_yticks(y)
    ax.set_yticklabels(res["subtype"])
    for i, r in res.reset_index(drop=True).iterrows():
        ax.text(101.5, i, f"n={int(r['n'])}", va="center", ha="left", fontsize=9, color="dimgray")

    # cosmetics
    ax.set_xlim(0, 110)  # leave space for n labels
    ax.set_xlabel("Sensitivity (True Positive %)")
    ax.set_title("Subtype Sensitivity (Recall): GPT vs XGB (ranked by |gap|)")
    ax.grid(axis="x", linestyle=":", alpha=0.35)
    if show_legend:
        # custom legend explaining line color = winner
        leg1 = ax.legend(loc="center left", bbox_to_anchor=(1.02, 0.6), frameon=False, title=None)
        # add a second legend for winner color cue
        from matplotlib.lines import Line2D
        handles = [
            Line2D([0], [0], color="dimgray", lw=4, label="Line: XGB better"),
            Line2D([0], [0], color="lightgray", lw=4, label="Line: GPT better"),
        ]
        ax.add_artist(leg1)
        ax.legend(handles=handles, loc="center left", bbox_to_anchor=(1.02, 0.42), frameon=False)

    plt.tight_layout()
    plt.show()

# Example:
plot_subtype_sensitivity_dumbbell(df_both, min_n=3, top_n=12)
