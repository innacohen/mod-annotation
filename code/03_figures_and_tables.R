


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
cw_df = read_csv("data/pipeline/crosswalk.csv") %>% select(-type)



# GLOBAL VARIABLES --------------------------------------------------------

TRAIN = cw_df %>%
  filter(split == "train") %>%
  pull(file_hash)

INT_VALIDATION = cw_df %>%
  filter(split == "test") %>%
  pull(file_hash)

EXT_VALIDATION = ant_pre_df %>% 
  select(file_hash, rare_subtype) %>%
  filter(rare_subtype != TRUE) %>%
  filter(!file_hash %in% c(TRAIN, INT_VALIDATION)) %>%
  pull(file_hash)


new_subtype_labels <- ant_pre_df %>%
  filter(file_hash %in% c(TRAIN, INT_VALIDATION, EXT_VALIDATION)) %>%
  select(file_hash, new_subtype_label) 

ant_excel_df2 = ant_excel_df %>%
  filter(file_hash %in% c(TRAIN, INT_VALIDATION, EXT_VALIDATION)) %>%
  clean_names() %>%
  select(row_id, file_hash, type, subtype_confidence, annotated, notes_free_text, subtype_1) %>% 
  distinct() %>%
  left_join(new_subtype_labels, by="file_hash") %>%
  left_join(cw_df, by="file_hash") %>%
  mutate(split = case_when(split == "train" ~ "train",
                           split == "test" ~ "internal validation",
                           file_hash %in% EXT_VALIDATION ~ "external_validation"))

table1(~type+new_subtype_label |split, data= ant_excel_df2)



# GLOBAL VARIABLES --------------------------------------------------------

names(cw_df)

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

