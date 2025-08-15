# Encode type for training
type_encoder, y_type_train_enc, _ = encode_labels(y_type_train, y_type_test)

type_cv_model = xgb.XGBClassifier(
    objective="multi:softmax",
    num_class=len(type_encoder.classes_),
    max_depth=6,
    learning_rate=0.1,
    n_estimators=100,
    subsample=0.8,
    colsample_bytree=0.8,
    eval_metric="mlogloss",
    random_state=SEED,
    n_jobs=1
)
type_cv_scores = cross_val_score(type_cv_model, X_train_final, y_type_train_enc, cv=cv, scoring="accuracy", n_jobs=1)
print(f"[Top-Down] Cross-validated TYPE accuracy: {type_cv_scores.mean():.4f} ± {type_cv_scores.std():.4f}")

type_model = type_cv_model.fit(X_train_final, y_type_train_enc)

# Train a subtype model for each TYPE
subtype_models = {}  # t_name -> {"model": xgb, "encoder": LabelEncoder, "fallback": str}
for t_idx, t_name in enumerate(type_encoder.classes_):
    mask = (y_type_train_enc == t_idx)
    X_t = X_train_final[mask]
    y_sub_t_raw = pd.Series(y_subtype_train)[mask].astype(str)
    if X_t.shape[0] == 0:
        continue
    sub_le = LabelEncoder().fit(y_sub_t_raw)
    y_sub_t = sub_le.transform(y_sub_t_raw)
    sub_model = xgb.XGBClassifier(
        objective="multi:softmax",
        num_class=len(sub_le.classes_),
        max_depth=6,
        learning_rate=0.1,
        n_estimators=100,
        subsample=0.8,
        colsample_bytree=0.8,
        eval_metric="mlogloss",
        random_state=SEED,
        n_jobs=1
    ).fit(X_t, y_sub_t)
    fallback_subtype = y_sub_t_raw.mode().iat[0]
    subtype_models[t_name] = {"model": sub_model, "encoder": sub_le, "fallback": fallback_subtype}

# Predict TYPE then route to per-TYPE subtype models
y_type_pred_enc_td = type_model.predict(X_test_final)
y_type_pred_td = type_encoder.inverse_transform(y_type_pred_enc_td)

y_subtype_pred_td = []
for i, pred_type in enumerate(y_type_pred_td):
    bundle = subtype_models.get(pred_type)
    if bundle is None:
        y_subtype_pred_td.append(pd.Series(y_subtype_train).mode().iat[0])
        continue
    model_t = bundle["model"]; enc_t = bundle["encoder"]
    pred_idx = model_t.predict(X_test_final.iloc[[i]])[0]
    pred_sub = enc_t.inverse_transform([pred_idx])[0]
    y_subtype_pred_td.append(pred_sub)
y_subtype_pred_td = np.array(y_subtype_pred_td)

# Evaluation
print("\n=== Held-Out Evaluation (Top-Down) ===")
print("TYPE Accuracy:", accuracy_score(y_type_test, y_type_pred_td))
print("\nSUBTYPE Accuracy (hierarchical; routed by PREDICTED TYPE):",
      accuracy_score(y_subtype_test, y_subtype_pred_td))
print("\nSUBTYPE Classification Report (hierarchical):")
print(classification_report(y_subtype_test, y_subtype_pred_td))

# Plots
plot_confusion(y_type_test, y_type_pred_td, labels=type_labels,
               title="TYPE Confusion Matrix (Counts) — Top-Down", figsize=(8, 6))
plot_confusion(y_type_test, y_type_pred_td, labels=type_labels,
               title="TYPE Confusion Matrix (Row-Normalized) — Top-Down", normalize="true", figsize=(8, 6))

plot_confusion(y_subtype_test, y_subtype_pred_td, labels=subtype_labels,
               title="SUBTYPE Confusion Matrix (Counts) — Top-Down", figsize=(14, 10))
plot_confusion(y_subtype_test, y_subtype_pred_td, labels=subtype_labels,
               title="SUBTYPE Confusion Matrix (Row-Normalized) — Top-Down", normalize="true", figsize=(14, 10))

# Feature importance (top-down)
type_feat_imp = xgb_gain_importance(type_model, X_train_final.columns)
plot_top_features(type_feat_imp, "Top 15 Features for TYPE (gain) — Top-Down")

print("\nTop 15 SUBTYPE feature importances per TYPE (gain):")
for t_name, bundle in subtype_models.items():
    s = xgb_gain_importance(bundle["model"], X_train_final.columns)
    print(f"\n[TYPE = {t_name}]")
    print(s.head(15))
    # Optionally: plot
plot_top_features(s, f"Top 15 Features for SUBTYPE | TYPE = {t_name} (gain)")