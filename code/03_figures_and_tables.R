


# IMPORT FUNCTIONS --------------------------------------------------------

source("code/_utils.R")


# IMPORT DATA -------------------------------------------------------------
setwd("~/palmer_scratch/mod-extract")
dd = read_csv("data/pipeline/feature_dd.csv")
xgb_feat_df = read_csv("data/pipeline/feature_importance_global.csv") 
pred_df = read_csv("data/pipeline/predictions_with_shap.csv")
ant_excel_df = read_excel("data/raw/model_db_annotations.xlsx") %>%
  clean_names() %>%
  filter(row_id <= 1300)
ant_long_df = read_csv("data/pipeline/ant_with_excluded_samples.csv")
ant_pre_df = read_csv("data/pipeline/preprocessed.csv")
ant_pre_df = read_csv("data/pipeline/preprocessed.csv")


# GLOBAL VARIABLES --------------------------------------------------------
INTERNAL_VALIDATION_SET = ant_pre_df$file_hash
EXTERNAL_VADLIATION_SET = ant_excel_df %>%
  filter(row_id > 1000) %>%
  pull(file_hash)



# PLOTS  -----------------------------------------------------------
plot_top_features(xgb_feat_df)
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

