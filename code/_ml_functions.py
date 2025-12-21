
def clean_numeric_columns(df):
    """Clean column names and enforce numeric dtype for object columns."""
    df = df.copy()
    df.columns = df.columns.astype(str).str.replace(r"[\[\]<>]", "_", regex=True)
    for col in df.columns:
        if df[col].dtype == "object":
            df[col] = pd.to_numeric(df[col], errors="raise")
    return df

def encode_labels(train_s, test_s):
    """Fit a LabelEncoder on train_s and transform both train/test (as strings)."""
    le = LabelEncoder().fit(pd.Series(train_s).astype(str))
    y_tr = le.transform(pd.Series(train_s).astype(str))
    y_te = le.transform(pd.Series(test_s).astype(str))
    return le, y_tr, y_te

def plot_confusion(y_true, y_pred, labels, title, normalize=None, figsize=(10, 7)):
    cm = confusion_matrix(y_true, y_pred, labels=labels, normalize=normalize)
    fmt = ".2f" if normalize else "d"
    plt.figure(figsize=figsize)
    sns.heatmap(cm, annot=True, fmt=fmt, cmap="Blues",
                xticklabels=labels, yticklabels=labels, linewidths=0.5)
    plt.xlabel("Predicted"); plt.ylabel("True"); plt.title(title)
    plt.xticks(rotation=90); plt.yticks(rotation=0)
    plt.tight_layout(); plt.show()

def xgb_gain_importance(estimator, feature_names):
    """Return gain-based importances mapped to real feature names as a sorted Series."""
    booster = estimator.get_booster()
    score = booster.get_score(importance_type="gain")  # dict: {key -> gain}
    mapped = {}
    for k, v in score.items():
        if isinstance(k, str) and k.startswith('f') and k[1:].isdigit():
            idx = int(k[1:])
            name = feature_names[idx] if idx < len(feature_names) else k
        else:
            name = k
        mapped[name] = float(v)
    s = pd.Series(mapped, dtype=float)
    s = s.reindex(feature_names).fillna(0.0).sort_values(ascending=False)
    return s

def plot_top_features(imp_series, title, topn=15, figsize=(9, 6)):
    top = imp_series.head(topn)[::-1]
    plt.figure(figsize=figsize)
    top.plot.barh()
    plt.title(title); plt.xlabel("Gain importance"); plt.ylabel("Feature")
    plt.tight_layout(); plt.show()

