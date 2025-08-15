library(tidyverse)

# Function to assign family
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

# Read predictions
df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

# --- Compute sensitivities and assign family ---
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    sens_xgb = mean(xgb_subtype_match, na.rm = TRUE),
    sens_gpt = mean(gpt_subtype_match, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(family = map_chr(true_subtype, infer_family))

# --- Sort by family, then XGB sensitivity ---
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens <- sens %>%
  mutate(family = factor(family, levels = family_order)) %>%
  arrange(family, desc(sens_xgb)) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype))))

# --- Reshape for plotting ---
sens_long <- sens %>%
  pivot_longer(cols = starts_with("sens_"),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# --- Plot ---
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_line(color = "#333333", linewidth = 1) +
  geom_point(aes(fill = model), shape = 21, size = 4, color = "#333333", stroke = 1) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Subtype Sensitivity: XGB vs GPT",
    x = "Sensitivity (TP %)",
    y = NULL,
    fill = "Model"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank()
  )




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

# Compute sensitivity & sort
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    sens_xgb = mean(xgb_subtype_match, na.rm = TRUE),
    sens_gpt = mean(gpt_subtype_match, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(family = map_chr(true_subtype, infer_family))

family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens <- sens %>%
  mutate(family = factor(family, levels = family_order)) %>%
  arrange(family, desc(sens_xgb)) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype))),
         change_sens = sens_gpt - sens_xgb)

# Plot arrows only
ggplot(sens, aes(x = sens_xgb, y = true_subtype)) +
  geom_path(
    aes(x = c(sens_xgb, sens_gpt), 
        y = true_subtype, 
        group = true_subtype,
        color = change_sens < 0),
    arrow = arrow(length = unit(0.3, "cm"), type = "closed"),
    linewidth = 1
  ) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_color_manual(values = c("TRUE" = "firebrick", "FALSE" = "steelblue")) +
  labs(
    title = "Subtype Sensitivity Change: XGB → GPT",
    x = "Sensitivity (TP %)",
    y = NULL
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "none"
  )
