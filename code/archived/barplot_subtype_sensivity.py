import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

def plot_subtype_sensitivity(df_both,
                             true_col="true_subtype",
                             gpt_col="gpt_pred_subtype",
                             xgb_col="xgb_pred_subtype",
                             figsize=(11, 9)):

    # ---- family detector ----
    def infer_family(s):
        s = str(s).strip()

        # Force both "I Other (...)" variants into Other
        if re.search(r'^\s*I\s+Other', s, flags=re.IGNORECASE):
            fam = "Other"
        # Receptors
        elif re.search(r'(^R\b|\bReceptor)', s, flags=re.IGNORECASE):
            fam = "Receptors"
        # H-current / Ih / HCN (robust to spaces)
        elif re.search(r'I\s*H\b|Ih\b|HCN|H-?current', s, flags=re.IGNORECASE):
            fam = "H-Current"
        # K first so "I K (Ca-activated)" stays K
        elif re.search(r'\bK\b|\bPotassium\b', s, flags=re.IGNORECASE):
            fam = "K"
        # Na
        elif re.search(r'\bNa\b|\bSodium\b', s, flags=re.IGNORECASE):
            fam = "Na"
        # Ca (after K)
        elif re.search(r'\bCa\b|\bCalcium\b', s, flags=re.IGNORECASE):
            fam = "Calcium"
        # Neither explicit
        elif re.search(r'\bNeither\b', s, flags=re.IGNORECASE):
            fam = "Neither"
        else:
            fam = "Other"
        return fam

    # ---- metrics ----
    df = df_both[[true_col, gpt_col, xgb_col]].dropna(subset=[true_col]).copy()
    subtypes = sorted(df[true_col].unique().tolist())

    rows = []
    for st in subtypes:
        total = (df[true_col] == st).sum()
        tp_xgb = ((df[true_col] == st) & (df[xgb_col] == st)).sum()
        tp_gpt = ((df[true_col] == st) & (df[gpt_col] == st)).sum()
        sens_xgb = tp_xgb / total if total else np.nan
        sens_gpt = tp_gpt / total if total else np.nan
        rows.append({
            "subtype": st,
            "family": infer_family(st),
            "total": total,
            "tp_xgb": tp_xgb, "sens_xgb": sens_xgb,
            "tp_gpt": tp_gpt, "sens_gpt": sens_gpt
        })

    res = pd.DataFrame(rows)

    # ---- hard family order with rank ----
    fam_rank = {
        "Calcium": 0,
        "H-Current": 1,
        "K": 2,
        "Na": 3,
        "Receptors": 4,
        "Other": 5,
        "Neither": 6,  # Z Neither at bottom
    }
    res["family"] = res["family"].map(lambda x: x if x in fam_rank else "Other")
    res["family_rank"] = res["family"].map(fam_rank).astype(int)

    # ---- subtype priority overrides (within-family) ----
    # Force I Ca (HVA) to top of Calcium; keep I Other (Leak/Rare) adjacent
    subtype_priority = {
        "I Ca (HVA)": -1,
        "I Other (Leak)": 0,
        "I Other (Rare)": 1,
    }
    res["sub_prio"] = res["subtype"].map(lambda s: subtype_priority.get(s, 999))

    # Sort: by family (custom), then priority, then XGB sens (desc), GPT (desc), total (desc)
    # ---- pick the best sensitivity within each subtype ----
    res["sens_best"] = res[["sens_xgb", "sens_gpt"]].max(axis=1)

    # Sort: by family (custom), then priority, then BEST sens (desc),
    # then XGB, then GPT, then total as final tie-breaker.
    res = res.sort_values(
        by=["family_rank", "sub_prio", "sens_best", "sens_xgb", "sens_gpt", "total"],
        ascending=[True, True, False, False, False, False],
        kind="mergesort"
    ).reset_index(drop=True)


    # ---- plot ----
    y = np.arange(len(res))
    h = 0.36
    fig, ax = plt.subplots(figsize=figsize)

    xgb_bars = ax.barh(y - h/2, res["sens_xgb"] * 100, height=h,
                       label="XGB (Dark)", color="dimgray")
    gpt_bars = ax.barh(y + h/2, res["sens_gpt"] * 100, height=h,
                       label="GPT (Light)", color="lightgray", edgecolor="gray")

    for i, (bx, bg) in enumerate(zip(xgb_bars, gpt_bars)):
        tp_xgb, total = int(res.iloc[i]["tp_xgb"]), int(res.iloc[i]["total"])
        tp_gpt = int(res.iloc[i]["tp_gpt"])

        # XGB label
        if bx.get_width() > 15:
            ax.text(bx.get_width() - 1, bx.get_y() + bx.get_height()/2,
                    f"{tp_xgb}/{total}", va="center", ha="right", fontsize=10, color="white")
        else:
            ax.text(bx.get_width() + 1, bx.get_y() + bx.get_height()/2,
                    f"{tp_xgb}/{total}", va="center", ha="left", fontsize=10)

        # GPT label
        if bg.get_width() > 15:
            ax.text(bg.get_width() - 1, bg.get_y() + bg.get_height()/2,
                    f"{tp_gpt}/{total}", va="center", ha="right", fontsize=10, color="black")
        else:
            ax.text(bg.get_width() + 1, bg.get_y() + bg.get_height()/2,
                    f"{tp_gpt}/{total}", va="center", ha="left", fontsize=10, color="dimgray")

    ax.set_yticks(y)
    ax.set_yticklabels(res["subtype"])
    ax.set_xlim(0, 105)
    ax.set_xlabel("Sensitivity (True Positive %)")
    ax.set_title("Subtype Sensitivity")
    ax.grid(axis="x", linestyle=":", alpha=0.4)

    # Black dashed separators between families
    fam_change_idx = np.where(res["family_rank"].shift() != res["family_rank"])[0]
    for idx in fam_change_idx:
        if idx > 0:
            ax.axhline(idx - 0.5, linestyle="--", color="black", alpha=0.4, linewidth=1)

    # Make first row appear at TOP (Calcium), last at BOTTOM (Neither)
    ax.invert_yaxis()

    ax.legend(loc="center left", bbox_to_anchor=(1.02, 0.5), frameon=False)
    plt.tight_layout()
    plt.show()

# call:
plot_subtype_sensitivity(df_both)


#==================================\
#Colorful
#===================================

import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

def plot_subtype_sensitivity(df_both,
                             true_col="true_subtype",
                             gpt_col="gpt_pred_subtype",
                             xgb_col="xgb_pred_subtype",
                             figsize=(11, 9)):

    # ---- family detector ----
    def infer_family(s):
        s = str(s).strip()

        if re.search(r'^\s*I\s+Other', s, flags=re.IGNORECASE):
            fam = "Other"
        elif re.search(r'(^R\b|\bReceptor)', s, flags=re.IGNORECASE):
            fam = "Receptors"
        elif re.search(r'I\s*H\b|Ih\b|HCN|H-?current', s, flags=re.IGNORECASE):
            fam = "H-Current"
        elif re.search(r'\bK\b|\bPotassium\b', s, flags=re.IGNORECASE):
            fam = "K"
        elif re.search(r'\bNa\b|\bSodium\b', s, flags=re.IGNORECASE):
            fam = "Na"
        elif re.search(r'\bCa\b|\bCalcium\b', s, flags=re.IGNORECASE):
            fam = "Calcium"
        elif re.search(r'\bNeither\b', s, flags=re.IGNORECASE):
            fam = "Neither"
        else:
            fam = "Other"
        return fam

    # ---- metrics ----
    df = df_both[[true_col, gpt_col, xgb_col]].dropna(subset=[true_col]).copy()
    subtypes = sorted(df[true_col].unique().tolist())

    rows = []
    for st in subtypes:
        total = (df[true_col] == st).sum()
        tp_xgb = ((df[true_col] == st) & (df[xgb_col] == st)).sum()
        tp_gpt = ((df[true_col] == st) & (df[gpt_col] == st)).sum()
        sens_xgb = tp_xgb / total if total else np.nan
        sens_gpt = tp_gpt / total if total else np.nan
        rows.append({
            "subtype": st,
            "family": infer_family(st),
            "total": total,
            "tp_xgb": tp_xgb, "sens_xgb": sens_xgb,
            "tp_gpt": tp_gpt, "sens_gpt": sens_gpt
        })

    res = pd.DataFrame(rows)

    # ---- hard family order ----
    fam_rank = {
        "Calcium": 0,
        "H-Current": 1,
        "K": 2,
        "Na": 3,
        "Receptors": 4,
        "Other": 5,
        "Neither": 6
    }
    res["family"] = res["family"].map(lambda x: x if x in fam_rank else "Other")
    res["family_rank"] = res["family"].map(fam_rank).astype(int)

    # ---- subtype priority overrides ----
    subtype_priority = {
        "I Ca (HVA)": -1,
        "I Other (Leak)": 0,
        "I Other (Rare)": 1,
    }
    res["sub_prio"] = res["subtype"].map(lambda s: subtype_priority.get(s, 999))

    # ---- sort ----
    res = res.sort_values(
        by=["family_rank", "sub_prio", "sens_xgb", "sens_gpt", "total"],
        ascending=[True, True, False, False, False],
        kind="mergesort"
    ).reset_index(drop=True)

    # ---- family colors ----
    family_colors = {
        "Calcium": "#1f77b4",     # blue
        "H-Current": "#ff7f0e",   # orange
        "K": "#2ca02c",           # green
        "Na": "#d62728",          # red
        "Receptors": "#9467bd",   # purple
        "Other": "#8c564b",       # brown
        "Neither": "#7f7f7f"      # gray
    }

    def adjust_color(color, factor):
        """Lighten or darken a color by factor <1=darken, >1=lighten"""
        c = mcolors.to_rgb(color)
        return tuple(min(max(ch * factor, 0), 1) for ch in c)

    # ---- plot ----
    y = np.arange(len(res))
    h = 0.36
    fig, ax = plt.subplots(figsize=figsize)

    xgb_bars = []
    gpt_bars = []

    for i, row in res.iterrows():
        base_color = family_colors[row["family"]]
        dark_color = adjust_color(base_color, 0.7)
        light_color = adjust_color(base_color, 1.4)

        xgb_bars.append(
            ax.barh(i - h/2, row["sens_xgb"] * 100, height=h,
                    color=dark_color)
        )
        gpt_bars.append(
            ax.barh(i + h/2, row["sens_gpt"] * 100, height=h,
                    color=light_color, edgecolor="gray")
        )

    # Add labels
    for i, row in res.iterrows():
        tp_xgb, total = int(row["tp_xgb"]), int(row["total"])
        tp_gpt = int(row["tp_gpt"])
        xgb_width = row["sens_xgb"] * 100
        gpt_width = row["sens_gpt"] * 100

        if xgb_width > 15:
            ax.text(xgb_width - 1, i - h/2, f"{tp_xgb}/{total}",
                    va="center", ha="right", fontsize=10, color="white")
        else:
            ax.text(xgb_width + 1, i - h/2, f"{tp_xgb}/{total}",
                    va="center", ha="left", fontsize=10)

        if gpt_width > 15:
            ax.text(gpt_width - 1, i + h/2, f"{tp_gpt}/{total}",
                    va="center", ha="right", fontsize=10, color="black")
        else:
            ax.text(gpt_width + 1, i + h/2, f"{tp_gpt}/{total}",
                    va="center", ha="left", fontsize=10, color="dimgray")

    ax.set_yticks(y)
    ax.set_yticklabels(res["subtype"])
    ax.set_xlim(0, 105)
    ax.set_xlabel("Sensitivity (True Positive %)")
    ax.set_title("Subtype Sensitivity (Recall) — grouped by Family (custom colors)")
    ax.grid(axis="x", linestyle=":", alpha=0.4)


    ax.invert_yaxis()
    ax.legend(
        [plt.Rectangle((0,0),1,1,color=family_colors[f]) for f in fam_rank.keys()],
        fam_rank.keys(), title="Family", loc="center left", bbox_to_anchor=(1.02, 0.5)
    )
    plt.tight_layout()
    plt.show()

# Call:
plot_subtype_sensitivity(df_both)
