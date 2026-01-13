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
