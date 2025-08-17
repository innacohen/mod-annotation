


# IMPORT FUNCTIONS --------------------------------------------------------

source("code/_utils.R")


# IMPORT DATA -------------------------------------------------------------
setwd("~/palmer_scratch/mod-extract")
dd = read_csv("data/pipeline/feature_dd.csv")
xgb_feat_df = read_csv("data/pipeline/feature_importance_global.csv") 
pred_df = read_csv("data/pipeline/predictions_with_shap.csv")
ant_raw_df = read_csv("data/pipeline/ant_with_excluded_samples.csv")
ant_pre_df = read_csv("data/pipeline/preprocessed.csv")


# FEATURES ----------------------------------------------------------------



plot_top_features(xgb_feat_df)
# Usage


# SENSIVITY  -----------------------------------------------------------
plot_arrow(pred_df)
plot_db(pred_df, order_by = "sens_xgb", facet_by_family = FALSE)
plot_db(pred_df, order_by = "abs_delta", facet_by_family = TRUE)
plot_db(pred_df, order_by = "abs_delta", facet_by_family = TRUE, labels = "minimal")
plot_db(pred_df, style = "winner", order_by = "abs_delta", facet_by_family = TRUE, labels = "minimal")
plot_db(pred_df, style = "winner", order_by = "abs_delta",
        facet_by_family = TRUE, labels = "minimal",
        annotate = "percent", percent_accuracy = 1)
plot_db(pred_df, style = "dumbbell", order_by = "sens_gpt",
        facet_by_family = FALSE, annotate = "counts")

plot_top_features(xgb_feat_df, top_n = 15, base_size=20, legend="minimal")
# print(p)
# ggsave("top_features.png", p, width = 8, height = 5, dpi = 300)

