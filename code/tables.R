
library(tidyverse)
library(naniar)
setwd("~/palmer_scratch/mod-extract/code")

sim_df = read_csv("../data/raw/sim_features_combined.csv")
pred_df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

sim_df2 <- sim_df %>%
  rename_with(~ paste0(., "_simfeat"), -mod_file)   # add "_simfeat" suffix to all but ID col

df <- pred_df %>%
  left_join(sim_df2, by = c("hash" = "mod_file"))

# Identify sim feature columns by suffix
sim_cols <- grep("_simfeat$", names(df), value = TRUE)

# Row-wise missingness counts & fractions
df <- df %>%
  mutate(
    misclassified = !xgb_subtype_match,
    n_missing_sim = rowSums(is.na(across(all_of(sim_cols)))),
    frac_missing_sim = n_missing_sim / length(sim_cols)
  )

# 1) Summary: misclassified vs correct
sum_tab <- df %>%
  group_by(misclassified) %>%
  summarise(
    n = n(),
    mean_missing = mean(n_missing_sim, na.rm = TRUE),
    median_missing = median(n_missing_sim, na.rm = TRUE),
    mean_frac_missing = mean(frac_missing_sim, na.rm = TRUE),
    median_frac_missing = median(frac_missing_sim, na.rm = TRUE),
    .groups = "drop"
  )
sum_tab



top_feats <- c(
  "ik_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_to_90_max_simfeat",
  "ik_interval2_time_to_90_recovery_simfeat",
  "ina_interval1_time_to_90_max_simfeat",
  "ina_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_min_to_90_max_simfeat",
  "voltage_simfeat"
)

# Summarise missingness proportions by misclassification
feat_missing_by_group <- df %>%
  group_by(misclassified) %>%
  summarise(across(all_of(top_feats), ~ mean(is.na(.)), .names = "pct_missing_{.col}")) %>%
  pivot_longer(
    cols = -misclassified,
    names_to = "feature",
    values_to = "pct_missing"
  ) %>%
  mutate(
    feature_clean = str_remove(feature, "^pct_missing_"),
    feature_clean = str_remove(feature_clean, "_simfeat$")
  )

# Plot
ggplot(feat_missing_by_group, aes(x = misclassified, y = feature_clean, fill = pct_missing)) +
  geom_tile() +
  scale_fill_continuous(labels = scales::percent) +
  labs(x = "Misclassified", y = "Top Feature", fill = "% Missing")


library(table1)
library(dplyr)

top_feats <- c(
  "ik_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_to_90_max_simfeat",
  "ik_interval2_time_to_90_recovery_simfeat",
  "ina_interval1_time_to_90_max_simfeat",
  "ina_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_min_to_90_max_simfeat",
  "voltage_simfeat"
)

# Make missingness indicators for these features
df_tab <- df %>%
  mutate(across(all_of(top_feats), ~ as.integer(is.na(.)), .names = "{.col}_na"))

# Create label map (to make table readable)
label_map <- setNames(
  gsub("_", " ", paste0(top_feats, " (Missing)")),
  paste0(top_feats, "_na")
)

# Build table1 (stratify by misclassified)
table1(~ ik_interval1_time_max_to_90_min_simfeat_na +
         ica_interval1_time_to_90_max_simfeat_na +
         ik_interval2_time_to_90_recovery_simfeat_na +
         ina_interval1_time_to_90_max_simfeat_na +
         ina_interval1_time_max_to_90_min_simfeat_na +
         ica_interval1_time_min_to_90_max_simfeat_na +
         voltage_simfeat_na | misclassified,
       data = df_tab,
       render.missing = NULL,
       labels = label_map)
