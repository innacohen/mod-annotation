


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

plot_top_features(xgb_feat_df, legend="minimal")

# DUMBELL PLOTS -----------------------------------------------------------

plot_db(pred_df, order_by = "sens_xgb", facet_by_family = FALSE)
plot_db(pred_df, order_by = "abs_delta", facet_by_family = TRUE)
plot_db(pred_df, order_by = "abs_delta", facet_by_family = TRUE, labels = "minimal")
plot_db(pred_df, style = "winner", order_by = "abs_delta", facet_by_family = TRUE, labels = "minimal")
plot_db(pred_df, style = "winner", order_by = "abs_delta",
        facet_by_family = TRUE, labels = "minimal",
        annotate = "percent", percent_accuracy = 1)
plot_db(pred_df, style = "dumbbell", order_by = "sens_gpt",
        facet_by_family = FALSE, annotate = "counts")
O



# Usage
plot_top_features(df_plot, top_n = 15, base_size=20, legend="minimal")
# print(p)
# ggsave("top_features.png", p, width = 8, height = 5, dpi = 300)


# ARROW -------------------------------------------------------------------
#todo: compare gpt to gpt + guidelines 
plot_arrow(pred_df)




# VERSION 3C2 BOTH -------------------------------------------------------------

library(tidyverse)

# --- Read and prep data ---

# Family inference
infer_family <- function(s) {
  s <- trimws(s)
  if (grepl("^I\\s*Other", s, ignore.case = TRUE)) {
    "Other"
  } else if (grepl("(^R\\b|Receptor)", s, ignore.case = TRUE)) {
    "Receptors"
  } else if (grepl("I\\s*H\\b|Ih\\b|HCN|H-?current", s, ignore.case = TRUE)) {
    "H-Current"
  } else if (grepl("\\bK\\b|Potassium", s, ignore.case = TRUE)) {
    "K"
  } else if (grepl("\\bNa\\b|Sodium", s, ignore.case = TRUE)) {
    "Na"
  } else if (grepl("\\bCa\\b|Calcium", s, ignore.case = TRUE)) {
    "Calcium"
  } else if (grepl("\\bNeither\\b", s, ignore.case = TRUE)) {
    "Neither"
  } else {
    "Other"
  }
}

# --- Build long-format counts ---
sens_long <- bind_rows(
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(xgb_subtype_match, na.rm = TRUE),
              total   = sum(!is.na(xgb_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "XGB"),
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(gpt_subtype_match, na.rm = TRUE),
              total   = sum(!is.na(gpt_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "GPT")
) %>%
  mutate(
    sensitivity = if_else(total > 0, correct / total, NA_real_),
    label = paste0(correct, "/", total),
    family = map_chr(true_subtype, infer_family)
  )

# --- Compute winner per subtype ---
winner_df <- sens_long %>%
  select(true_subtype, model, sensitivity) %>%
  pivot_wider(names_from = model, values_from = sensitivity) %>%
  mutate(
    diff = GPT - XGB,
    winner = case_when(
      is.na(GPT) | is.na(XGB) ~ "Tie", # conservative if missing
      diff >  0 ~ "GPT",
      diff <  0 ~ "XGB",
      TRUE      ~ "Tie"
    )
  ) %>%
  select(true_subtype, winner, diff)

# --- Merge winner info back ---
sens_long <- sens_long %>%
  left_join(winner_df, by = "true_subtype")

# --- Order families and subtypes ---
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens_long <- sens_long %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# --- Legend categories (for winners & ties only) ---
sens_long <- sens_long %>%
  mutate(
    point_category = case_when(
      winner == "Tie" ~ "Tie",
      model == winner ~ paste0("Winner: ", winner),
      TRUE            ~ "Runner-up"
    )
  )

# Colors for the legend categories
legend_colors <- c(
  "Winner: GPT" = "firebrick",
  "Winner: XGB" = "steelblue",
  "Tie"         = "grey50"
)

# --- Plot ---
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  # connecting line between the two model points
  geom_line(color = "#999999", linewidth = 0.8, show.legend = FALSE) +
  
  # winners and ties (these feed the legend)
  geom_point(
    data = filter(sens_long, point_category %in% c("Winner: GPT", "Winner: XGB", "Tie")),
    aes(fill = point_category),
    shape = 21, size = 4, color = "black", stroke = 1
  ) +
  
  # runner-up points (kept out of legend)
  geom_point(
    data = filter(sens_long, point_category == "Runner-up"),
    shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8,
    show.legend = FALSE
  ) +
  
  # labels for winners and ties (on the right)
  geom_text(
    data = filter(sens_long, point_category %in% c("Winner: GPT", "Winner: XGB", "Tie")),
    aes(label = label),
    hjust = -0.3, size = 3, color = "black",
    nudge_x = 0.01, show.legend = FALSE
  ) +
  
  # labels for runner-up (on the left)
  geom_text(
    data = filter(sens_long, point_category == "Runner-up"),
    aes(label = label),
    hjust = 1.3, size = 3, color = "black",
    show.legend = FALSE
  ) +
  
  scale_fill_manual(values = legend_colors, name = NULL) +
  scale_x_continuous(
    labels = scales::percent_format(accuracy = 1),
    limits = c(0, 1.05),
    expand = expansion(mult = c(0.01, 0.06))
  ) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Subtype Sensitivity",
    subtitle = "",
    x = "Sensitivity (TP %)",
    y = NULL
  ) +
  theme_minimal(base_size = 20) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.text.y = element_blank(),
    legend.position = "bottom",
    axis.text.y = element_text(color = "black"),
    axis.ticks.y = element_line(color = "black")
  )



# VERSION 3D BOTH --------------------------------------------------------------
library(tidyverse)

# --- Read and prep data ---
df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

# Family inference
infer_family <- function(s) {
  s <- trimws(s)
  if (grepl("^I\\s*Other", s, ignore.case = TRUE)) {
    "Other"
  } else if (grepl("(^R\\b|Receptor)", s, ignore.case = TRUE)) {
    "Receptors"
  } else if (grepl("I\\s*H\\b|Ih\\b|HCN|H-?current", s, ignore.case = TRUE)) {
    "H-Current"
  } else if (grepl("\\bK\\b|Potassium", s, ignore.case = TRUE)) {
    "K"
  } else if (grepl("\\bNa\\b|Sodium", s, ignore.case = TRUE)) {
    "Na"
  } else if (grepl("\\bCa\\b|Calcium", s, ignore.case = TRUE)) {
    "Calcium"
  } else if (grepl("\\bNeither\\b", s, ignore.case = TRUE)) {
    "Neither"
  } else {
    "Other"
  }
}

# Build long-format counts directly
sens_long <- bind_rows(
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(xgb_subtype_match, na.rm = TRUE),
              total = sum(!is.na(xgb_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "XGB"),
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(gpt_subtype_match, na.rm = TRUE),
              total = sum(!is.na(gpt_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "GPT")
) %>%
  mutate(
    sensitivity = correct / total,
    label = paste0(correct, "/", total, " (", round(100 * sensitivity), "%)"),
    family = map_chr(true_subtype, infer_family)
  )

# Compute winner per subtype
winner_df <- sens_long %>%
  select(true_subtype, model, sensitivity) %>%
  pivot_wider(names_from = model, values_from = sensitivity) %>%
  mutate(
    diff = GPT - XGB,
    winner = case_when(
      diff > 0 ~ "GPT",
      diff < 0 ~ "XGB",
      TRUE ~ "Tie"
    )
  ) %>%
  select(true_subtype, winner, diff)

# Merge winner info back
sens_long <- sens_long %>%
  left_join(winner_df, by = "true_subtype")

# Order families and subtypes
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens_long <- sens_long %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# Colors
winner_colors <- c("GPT" = "firebrick", "XGB" = "steelblue")

# Plot
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_line(color = "#999999", linewidth = 0.8) +
  
  geom_point(
    data = filter(sens_long, model == winner & winner != "Tie"),
    aes(fill = model),
    shape = 21, size = 4, color = "black", stroke = 1
  ) +
  scale_fill_manual(values = winner_colors, guide = "none") +
  
  geom_point(
    data = filter(sens_long, model != winner & winner != "Tie"),
    shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8
  ) +
  
  geom_point(
    data = filter(sens_long, winner == "Tie"),
    shape = 21, size = 4, fill = "grey50", color = "black", stroke = 1
  ) +
  
  geom_text(
    data = filter(sens_long, model == winner & winner != "Tie"),
    aes(label = label),
    hjust = -0.3, size = 3, color = "black",
    nudge_x = 0.01
  ) +
  geom_text(
    data = filter(sens_long, model != winner & winner != "Tie"),
    aes(label = label),
    hjust = 1.3, size = 3, color = "black"
  ) +
  geom_text(
    data = filter(sens_long, winner == "Tie"),
    aes(label = label),
    hjust = -0.3, size = 3, color = "black"
  ) +
  
  scale_x_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.1)) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = "Winner in color; loser as hollow black circle; counts and percentages shown for each",
    x = "Sensitivity (TP %)",
    y = NULL
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.text.y = element_blank(),
    legend.position = "none"
  )


# WINNER MARGIN ---------------------------------------------------------------
library(tidyverse)

# --- Read and prep data ---
df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

# Family inference
infer_family <- function(s) {
  s <- trimws(s)
  if (grepl("^I\\s*Other", s, ignore.case = TRUE)) {
    "Other"
  } else if (grepl("(^R\\b|Receptor)", s, ignore.case = TRUE)) {
    "Receptors"
  } else if (grepl("I\\s*H\\b|Ih\\b|HCN|H-?current", s, ignore.case = TRUE)) {
    "H-Current"
  } else if (grepl("\\bK\\b|Potassium", s, ignore.case = TRUE)) {
    "K"
  } else if (grepl("\\bNa\\b|Sodium", s, ignore.case = TRUE)) {
    "Na"
  } else if (grepl("\\bCa\\b|Calcium", s, ignore.case = TRUE)) {
    "Calcium"
  } else if (grepl("\\bNeither\\b", s, ignore.case = TRUE)) {
    "Neither"
  } else {
    "Other"
  }
}

# Build sensitivity data
sens_long <- bind_rows(
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(xgb_subtype_match, na.rm = TRUE),
              total = sum(!is.na(xgb_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "XGB"),
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(gpt_subtype_match, na.rm = TRUE),
              total = sum(!is.na(gpt_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "GPT")
) %>%
  mutate(
    sensitivity = correct / total,
    family = map_chr(true_subtype, infer_family)
  )

# Compute winner margin: XGB - GPT
winner_df <- sens_long %>%
  select(true_subtype, model, sensitivity, family) %>%
  pivot_wider(names_from = model, values_from = sensitivity) %>%
  mutate(
    diff = XGB - GPT,
    winner = case_when(
      diff > 0 ~ "XGB",   # XGB ahead
      diff < 0 ~ "GPT",   # GPT ahead
      TRUE ~ "Tie"
    )
  )

# Order subtypes by family then abs(diff)
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")
winner_df <- winner_df %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# Colors: Positive = Blue (XGB ahead), Negative = Red (GPT ahead), Tie = Grey
winner_colors <- c("XGB" = "steelblue", "GPT" = "firebrick", "Tie" = "grey50")

# --- Bar plot ---
ggplot(winner_df, aes(x = diff, y = true_subtype, fill = winner)) +
  geom_col() +
  geom_text(aes(label = paste0(round(diff * 100), "%")),
            hjust = ifelse(winner_df$diff > 0, -0.3, 1.3),
            color = "black", size = 5) +
  scale_fill_manual(values = winner_colors, guide = "none") +
  geom_vline(xintercept = 0, color = "black") +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(min(winner_df$diff) - 0.05, max(winner_df$diff) + 0.05)) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Winner Margin by Subtype",
    subtitle = "",
    x = "Difference in Sensitivity (XGB − GPT)",
    y = NULL
  ) +
  theme_minimal(base_size = 20) +
  theme(
    panel.grid.major.y = element_blank(),
    strip.text.y = element_blank()
  )

#Positive (blue) = XGB higher sensitivity; Negative (red) = GPT higher sensitivity


# TYPE FIGURE -------------------------------------------------------------
library(tidyverse)
library(scales)

# --- Compute accuracies ---
acc_type_xgb <- mean(df$true_type == df$xgb_pred_type, na.rm = TRUE)
acc_type_gpt <- mean(df$true_type == df$gpt_pred_type, na.rm = TRUE)

acc_sub_xgb  <- mean(df$true_subtype == df$xgb_pred_subtype, na.rm = TRUE)
acc_sub_gpt  <- mean(df$true_subtype == df$gpt_pred_subtype, na.rm = TRUE)

# --- Combine into one tibble ---
acc_all <- tibble(
  Level    = factor(rep(c("Type", "Subtype"), each = 2), levels = c("Type", "Subtype")),
  Model    = factor(rep(c("XGB", "GPT"), times = 2), levels = c("XGB", "GPT")),
  Accuracy = c(acc_type_xgb, acc_type_gpt, acc_sub_xgb, acc_sub_gpt)
)

# --- Plot ---
ggplot(acc_all, aes(x = Level, y = Accuracy, fill = Model)) +
  geom_col(position = position_dodge(width = 0.6), width = 0.55) +
  geom_text(aes(label = percent(Accuracy, accuracy = 0.1), group = Model),
            position = position_dodge(width = 0.6), vjust = -0.5, size = 8) +
  scale_y_continuous(limits = c(0, 1), labels = percent) +
  scale_fill_manual(values = c("XGB" = "steelblue", "GPT" = "firebrick")) +
  labs(title = "", 
       x = NULL, y = "Accuracy") +
  theme_minimal(base_size = 20) +
  theme(legend.title = element_blank(),
        plot.title = element_text(face = "bold"))




# OTHERS ------------------------------------------------------------------


# PANEL PLOT --------------------------------------------------------------
library(tidyverse)
library(patchwork)

# --- Read and prep data ---
df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

# Family inference
infer_family <- function(s) {
  s <- trimws(s)
  if (grepl("^I\\s*Other", s, ignore.case = TRUE)) {
    "Other"
  } else if (grepl("(^R\\b|Receptor)", s, ignore.case = TRUE)) {
    "Receptors"
  } else if (grepl("I\\s*H\\b|Ih\\b|HCN|H-?current", s, ignore.case = TRUE)) {
    "H-Current"
  } else if (grepl("\\bK\\b|Potassium", s, ignore.case = TRUE)) {
    "K"
  } else if (grepl("\\bNa\\b|Sodium", s, ignore.case = TRUE)) {
    "Na"
  } else if (grepl("\\bCa\\b|Calcium", s, ignore.case = TRUE)) {
    "Calcium"
  } else if (grepl("\\bNeither\\b", s, ignore.case = TRUE)) {
    "Neither"
  } else {
    "Other"
  }
}

# Build sensitivity data
sens_long <- bind_rows(
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(xgb_subtype_match, na.rm = TRUE),
              total = sum(!is.na(xgb_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "XGB"),
  df %>%
    group_by(true_subtype) %>%
    summarise(correct = sum(gpt_subtype_match, na.rm = TRUE),
              total = sum(!is.na(gpt_subtype_match)),
              .groups = "drop") %>%
    mutate(model = "GPT")
) %>%
  mutate(
    sensitivity = correct / total,
    family = map_chr(true_subtype, infer_family)
  )

# Compute winner margin: XGB - GPT
winner_df <- sens_long %>%
  select(true_subtype, model, sensitivity, family) %>%
  pivot_wider(names_from = model, values_from = sensitivity) %>%
  mutate(
    diff = XGB - GPT,
    winner = case_when(
      diff > 0 ~ "XGB",
      diff < 0 ~ "GPT",
      TRUE ~ "Tie"
    )
  )

# Merge winner info into sens_long
sens_long <- sens_long %>%
  left_join(winner_df %>% select(true_subtype, winner, diff), by = "true_subtype")

# Order subtypes
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")
sens_long <- sens_long %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

winner_df <- sens_long %>%
  distinct(true_subtype, family, diff, winner) %>%
  mutate(true_subtype = factor(true_subtype, levels = levels(sens_long$true_subtype)))

# Precompute offsets for text labels
sens_long <- sens_long %>%
  mutate(
    text_hjust = ifelse(model == "XGB", 1.3, -0.3),
    text_nudge = ifelse(model == "GPT", 0.01, 0)
  )

# Colors
winner_colors <- c("XGB" = "steelblue", "GPT" = "firebrick", "Tie" = "grey50")

# --- Left panel: Counts dumbbell plot ---
p_counts <- ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_line(color = "#999999", linewidth = 0.8) +
  geom_point(data = filter(sens_long, model == winner & winner != "Tie"),
             aes(fill = model), shape = 21, size = 4, color = "black", stroke = 1) +
  scale_fill_manual(values = winner_colors, guide = "none") +
  geom_point(data = filter(sens_long, model != winner & winner != "Tie"),
             shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8) +
  geom_point(data = filter(sens_long, winner == "Tie"),
             shape = 21, size = 4, fill = "grey50", color = "black", stroke = 1) +
  geom_text(aes(label = paste0(correct, "/", total)),
            hjust = sens_long$text_hjust, nudge_x = sens_long$text_nudge,
            size = 3, color = "black") +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.1)) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(subtitle = "Counts (correct / total)", x = "Sensitivity (TP %)", y = NULL) +
  theme_minimal(base_size = 14) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor.x = element_blank(),
        strip.text.y = element_blank(), legend.position = "none")

# --- Right panel: Margin bar plot ---
p_margin <- ggplot(winner_df, aes(x = diff, y = true_subtype, fill = winner)) +
  geom_col() +
  geom_text(aes(label = paste0(round(diff * 100), "%")),
            hjust = ifelse(winner_df$diff > 0, -0.3, 1.3),
            color = "black", size = 3) +
  scale_fill_manual(values = winner_colors, guide = "none") +
  geom_vline(xintercept = 0, color = "black", linewidth = 0.6) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                     limits = c(min(winner_df$diff) - 0.05, max(winner_df$diff) + 0.05)) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(subtitle = "Margin (XGB − GPT)", x = "Difference in Sensitivity", y = NULL) +
  theme_minimal(base_size = 14) +
  theme(panel.grid.major.y = element_blank(), strip.text.y = element_blank(),
        legend.position = "none")

# --- Combine ---
p_counts + p_margin + plot_annotation(
  title = "Subtype Sensitivity: XGB vs GPT",
  subtitle = "Left: absolute performance with counts; Right: XGB − GPT margin (blue = XGB ahead, red = GPT ahead)"
)


