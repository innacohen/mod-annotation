
library(tidyverse)
library(naniar)
library(table1)
setwd("~/palmer_scratch/mod-extract/code")




### Render p-value
# Concise output for followup table (only Yes's, instead of Yes/No)
#Show the mean (SD) and median (IQR) for continuous variables
pvalue <- function(x, ...) {
  # Construct vectors of data y, and groups (strata) g
  y <- unlist(x)
  g <- factor(rep(1:length(x), times = sapply(x, length)))
  
  if (is.numeric(y)) {
    # For numeric variables with more than two groups, perform a one-way ANOVA
    if (length(unique(g)) > 2) {
      p <- summary(aov(y ~ g))[[1]]["Pr(>F)"][1]
    } else {
      # For exactly two groups, use a t-test
      p <- t.test(y ~ g)$p.value
    }
  } else {
    # For categorical variables, perform a chi-squared test of independence
    p <- chisq.test(table(y, g))$p.value
  }
  
  # Format the p-value without HTML substitution
  c("", format.pval(p, digits = 3, eps = 0.001))
}







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


# TABLES ------------------------------------------------------------------



df %>%
  select(true_type, true_subtype, gpt_type_match, gpt_subtype_match, xgb_subtype_match, ik_interval1_time_max_to_90_min_simfeat) %>%
  mutate(xgb_subtype_match = factor(xgb_subtype_match, levels=c(FALSE,TRUE), labels=c("XGB Wrong","XGB Correct"))) %>%
  table1(~.|xgb_subtype_match, data=., overall=F, extra.col=list(`P-value`=pvalue))

df %>%
  select(true_type, true_subtype, xgb_subtype_match, starts_with("ik_")) %>%
  mutate(xgb_subtype_match = factor(xgb_subtype_match, levels=c(FALSE,TRUE), labels=c("XGB Wrong","XGB Correct"))) %>%
  filter(true_type == "I K") %>%
  table1(~.|xgb_subtype_match, data=., overall=F, extra.col=list(`P-value`=pvalue))



# BOX PLOT ----------------------------------------------------------------

library(dplyr)
library(ggplot2)
library(ggpubr)   # for stat_compare_means
library(scales)

# Prep data
df_plot <- df %>%
  mutate(class_outcome = ifelse(misclassified, "Misclassified", "Correct"))

# Medians (and label text)
meds <- df_plot %>%
  group_by(class_outcome) %>%
  summarise(median_val = median(frac_missing_sim, na.rm = TRUE), .groups = "drop") %>%
  mutate(median_lab = paste0("Median = ", percent(median_val, accuracy = 1)))

# Boxplot + medians + p-value + median labels
ggplot(df_plot, aes(x = class_outcome, y = frac_missing_sim, fill = class_outcome)) +
  geom_boxplot(outlier.shape = 21, outlier.size = 1.5, alpha = 0.8) +
  # median marker
  geom_point(data = meds, aes(y = median_val), color = "black", size = 3, shape = 18) +
  # median label (nudged slightly above the diamond)
  geom_text(data = meds, aes(y = median_val, label = median_lab),
            vjust = -1, size = 3.3, color = "black") +
  scale_fill_manual(values = c("Correct" = "#1f77b4", "Misclassified" = "#d62728")) +
  labs(x = NULL, y = "Fraction of missing simulation features") +
  theme_bw(base_size = 12) +
  theme(legend.position = "none",
        axis.text.x = element_text(size = 11, face = "bold"),
        axis.text.y = element_text(size = 10)) +
  # Wilcoxon p-value annotation
  stat_compare_means(method = "wilcox.test",
                     comparisons = list(c("Correct", "Misclassified")),
                     label = "p.format",
                     label.y = 1.05) +                     # tweak if it clips
  coord_cartesian(ylim = c(0, 1.1))                       # leaves room for p-value/labels




library(dplyr); library(tidyr); library(stringr); library(ggplot2); library(scales)

# your top features (from your importance plot)
top_feats <- c(
  "ik_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_to_90_max_simfeat",
  "ik_interval2_time_to_90_recovery_simfeat",
  "ina_interval1_time_to_90_max_simfeat",
  "ina_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_min_to_90_max_simfeat",
  "voltage_simfeat"
)

# long format with % missing per group
miss_long <- df %>%
  select(misclassified, all_of(top_feats)) %>%
  pivot_longer(-misclassified, names_to="feature", values_to="val") %>%
  mutate(feature_clean = str_remove(feature, "_simfeat$"),
         is_missing = is.na(val)) %>%
  group_by(misclassified, feature, feature_clean) %>%
  summarise(pct_missing = mean(is_missing), n = n(), .groups="drop")

# order features by your importance ranking
miss_long$feature_clean <- factor(miss_long$feature_clean, levels = str_remove(top_feats, "_simfeat$"))

ggplot(miss_long,
       aes(x = pct_missing, y = feature_clean,
           color = ifelse(misclassified, "Misclassified", "Correct"))) +
  geom_point(position = position_dodge(width = 0.5), size = 5) +
  scale_x_continuous(labels = percent) +
  scale_color_manual(values = c("Correct" = "#1f77b4",      # blue
                                "Misclassified" = "#e377c2")) + # pink
  labs(x = "% Missing", y = "Top simulation feature", color = NULL) +
  theme_bw() +
  theme(
    legend.position = "top",
    axis.text.y = element_text(size = 20),
    axis.text.x = element_text(size = 20)
  )



library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(scales)

top_feats <- c(
  "ik_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_to_90_max_simfeat",
  "ik_interval2_time_to_90_recovery_simfeat",
  "ina_interval1_time_to_90_max_simfeat",
  "ina_interval1_time_max_to_90_min_simfeat",
  "ica_interval1_time_min_to_90_max_simfeat",
  "voltage_simfeat"
)

# Reshape with subtype carried along
miss_long <- df %>%
  select(true_subtype, misclassified, all_of(top_feats)) %>%
  pivot_longer(-c(true_subtype, misclassified),
               names_to = "feature", values_to = "val") %>%
  mutate(feature_clean = str_remove(feature, "_simfeat$"),
         is_missing = is.na(val)) %>%
  group_by(true_subtype, misclassified, feature, feature_clean) %>%
  summarise(pct_missing = mean(is_missing), n = n(), .groups = "drop")

# Keep features ordered by importance
miss_long$feature_clean <- factor(miss_long$feature_clean,
                                  levels = str_remove(top_feats, "_simfeat$"))

# Scatter plot with facets by true_subtype
ggplot(miss_long,
       aes(x = pct_missing, y = feature_clean,
           color = ifelse(misclassified, "Misclassified", "Correct"))) +
  geom_point(position = position_dodge(width = 0.6), size = 2.5) +
  scale_x_continuous(labels = percent) +
  scale_color_manual(values = c("Correct" = "#1f77b4",      # blue
                                "Misclassified" = "#e377c2")) + # pink
  labs(x = "% Missing", y = "Top simulation feature", color = NULL) +
  facet_wrap(~ true_subtype, scales = "free_y") +   # facet by subtype
  theme_bw() +
  theme(
    legend.position = "top",
    axis.text.y = element_text(size = 8),
    strip.text = element_text(size = 9, face = "bold")
  )




# BARPLOT -----------------------------------------------------------------
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(scales)

# 1) Identify all *_simfeat columns that are numeric
all_feats <- names(df)[grepl("_simfeat$", names(df)) & sapply(df, is.numeric)]

# 2) Long format with missingness
long_all <- df %>%
  select(true_subtype, misclassified, all_of(all_feats)) %>%
  pivot_longer(-c(true_subtype, misclassified),
               names_to = "feature", values_to = "val") %>%
  mutate(feature_clean = str_remove(feature, "_simfeat$"),
         is_missing = is.na(val))

# 3) % missing per group
pct_by_grp_all <- long_all %>%
  group_by(true_subtype, feature_clean, misclassified) %>%
  summarise(pct_missing = mean(is_missing), .groups = "drop")

# 4) Pivot wide + compute delta
delta_all <- pct_by_grp_all %>%
  pivot_wider(names_from = misclassified, values_from = pct_missing,
              names_prefix = "pct_missing_") %>%
  mutate(delta = pct_missing_TRUE - pct_missing_FALSE)

# 5) Collapse across subtypes (overall effect per feature)
overall_all <- delta_all %>%
  group_by(feature_clean) %>%
  summarise(delta = mean(delta, na.rm = TRUE), .groups = "drop") %>%
  mutate(sign = ifelse(delta > 0, "More in Misclassified", "More in Correct"))

# 6) Diverging bar chart across all numeric features
ggplot(overall_all,
       aes(x = reorder(feature_clean, delta), y = delta, fill = sign)) +
  geom_col(width = 0.8) +
  coord_flip() +
  geom_hline(yintercept = 0, linetype = 2) +
  scale_y_continuous(labels = percent) +
  scale_fill_manual(values = c("More in Correct" = "steelblue",
                               "More in Misclassified" = "firebrick")) +
  labs(x = NULL,
       y = "Δ % Missing (Misclassified − Correct)",
       fill = NULL) +
  theme_bw(base_size = 11) +
  theme(legend.position = "top",
        axis.text.y = element_text(size = 6))


# facet -------------------------------------------------------------------
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(scales)

# helper: list available subtypes
unique(df$true_subtype)

plot_delta_missing_for_subtype <- function(subtype,
                                           top_n = 25,         # show top N by |delta|
                                           min_abs_delta = 0,  # or threshold by absolute delta
                                           base_size = 11) {
  # 1) numeric *_simfeat features only
  simfeats <- names(df)[grepl("_simfeat$", names(df)) & sapply(df, is.numeric)]
  stopifnot(length(simfeats) > 0)
  
  # 2) Filter to requested subtype and go long
  long_one <- df %>%
    filter(true_subtype == subtype) %>%
    select(misclassified, all_of(simfeats)) %>%
    pivot_longer(-misclassified, names_to = "feature", values_to = "val") %>%
    transmute(
      misclassified,
      feature_clean = str_remove(feature, "_simfeat$"),
      is_missing = is.na(val)
    )
  
  # If no rows for this subtype, bail early
  if (nrow(long_one) == 0) {
    stop("No rows found for subtype: ", subtype)
  }
  
  # 3) % missing per group, then wide, then delta
  delta_df <- long_one %>%
    group_by(feature_clean, misclassified) %>%
    summarise(pct_missing = mean(is_missing), .groups = "drop") %>%
    pivot_wider(names_from = misclassified, values_from = pct_missing,
                names_prefix = "pct_missing_") %>%
    # some features may be all-NA or all-present; handle safely
    mutate(
      pct_missing_TRUE  = coalesce(pct_missing_TRUE,  0),
      pct_missing_FALSE = coalesce(pct_missing_FALSE, 0),
      delta = pct_missing_TRUE - pct_missing_FALSE,
      sign  = ifelse(delta > 0, "More in Misclassified", "More in Correct")
    )
  
  # 4) filter by effect size (optional)
  delta_df <- delta_df %>%
    filter(abs(delta) >= min_abs_delta) %>%
    arrange(desc(abs(delta))) %>%
    { if (!is.null(top_n)) head(., top_n) else . } %>%
    mutate(feature_clean = factor(feature_clean, levels = rev(.$feature_clean)))
  
  # 5) plot
  ggplot(delta_df, aes(x = feature_clean, y = delta, fill = sign)) +
    geom_col(width = 0.8) +
    coord_flip() +
    geom_hline(yintercept = 0, linetype = 2) +
    scale_y_continuous(labels = percent) +
    scale_fill_manual(values = c("More in Correct" = "#1f77b4",   # blue
                                 "More in Misclassified" = "#e377c2")) + # pink
    labs(x = NULL,
         y = "Δ % Missing (Misclassified − Correct)",
         fill = NULL,
         title = subtype) +
    theme_bw(base_size = base_size) +
    theme(legend.position = "top",
          axis.text.y = element_text(size = base_size - 3))
}

# Example usage:
plot_delta_missing_for_subtype("I H")
plot_delta_missing_for_subtype("I Na (General)")
# plot_delta_missing_for_subtype("I H", min_abs_delta = 0.05)   # only show |Δ| ≥ 5%






# facet -------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(scales)
library(tidytext)   # for reorder_within / scale_y_reordered

# Which subtypes to include (exact text)
keep_subtypes <- c(
  "I H",
  "I K (A-type)",
  "I K (Ca-activated)",
  "I K (Delayed Rectifier)",
  "I K (M-type)",
  "I K (Rare)",
  "I Na (General)"
)

# 1) numeric *_simfeat features only
simfeats <- names(df)[grepl("_simfeat$", names(df)) & sapply(df, is.numeric)]

# 2) Long format with missingness
long_all <- df %>%
  select(true_subtype, misclassified, all_of(simfeats)) %>%
  pivot_longer(-c(true_subtype, misclassified),
               names_to = "feature", values_to = "val") %>%
  mutate(feature_clean = str_remove(feature, "_simfeat$"),
         is_missing = is.na(val))

# 3) % missing per group (Correct vs Misclassified)
pct_by_grp_all <- long_all %>%
  group_by(true_subtype, feature_clean, misclassified) %>%
  summarise(pct_missing = mean(is_missing), .groups = "drop")

# 4) Pivot wide + compute delta, then filter to selected subtypes
delta_all <- pct_by_grp_all %>%
  pivot_wider(names_from = misclassified, values_from = pct_missing,
              names_prefix = "pct_missing_") %>%
  mutate(
    pct_missing_TRUE  = coalesce(pct_missing_TRUE,  0),
    pct_missing_FALSE = coalesce(pct_missing_FALSE, 0),
    delta = pct_missing_TRUE - pct_missing_FALSE,
    sign  = ifelse(delta > 0, "More in Misclassified", "More in Correct")
  ) %>%
  filter(true_subtype %in% keep_subtypes)

# (Optional) keep only the largest |Δ| per facet so labels are readable
top_n_per_facet <- 20
delta_top <- delta_all %>%
  group_by(true_subtype) %>%
  slice_max(order_by = abs(delta), n = top_n_per_facet, with_ties = FALSE) %>%
  ungroup()

# 5) Faceted diverging bars (horizontal), ordered within each facet
ggplot(delta_top,
       aes(x = delta,
           y = reorder_within(feature_clean, delta, true_subtype),
           fill = sign)) +
  geom_col(width = 0.8) +
  geom_vline(xintercept = 0, linetype = 2) +
  scale_x_continuous(labels = percent) +
  scale_y_reordered() +
  scale_fill_manual(values = c("More in Correct" = "#1f77b4",     # blue
                               "More in Misclassified" = "#e377c2")) + # pink
  labs(x = "Δ % Missing (Misclassified − Correct)",
       y = NULL,
       fill = NULL) +
  facet_wrap(~ true_subtype, scales = "free_y") +
  theme_bw(base_size = 10) +
  theme(
    legend.position = "top",
    axis.text.y = element_text(size = 6.5),
    strip.text = element_text(size = 9, face = "bold")
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

