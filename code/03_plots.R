

# ARROWS ------------------------------------------------------------------


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

# Reshape to long format for arrows
sens_long <- sens %>%
  pivot_longer(cols = c(sens_xgb, sens_gpt),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# Plot arrows (one per subtype)
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_path(
    aes(color = change_sens < 0),
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



# VERSION 2A ---------------------------------------------------------------


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
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype))))

# Reshape for plotting
sens_long <- sens %>%
  pivot_longer(cols = c(sens_xgb, sens_gpt),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# Plot sleek dots + line
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_line(color = "#999999", linewidth = 0.8) +
  geom_point(aes(fill = model), shape = 21, size = 4, color = "#333333", stroke = 1) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_fill_manual(values = c("XGB" = "steelblue", "GPT" = "firebrick")) +
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


# VERSION 2B - FACET ------------------------------------------------------

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

# Compute sensitivity & winner
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    sens_xgb = mean(xgb_subtype_match, na.rm = TRUE),
    sens_gpt = mean(gpt_subtype_match, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    family = map_chr(true_subtype, infer_family),
    diff = sens_gpt - sens_xgb
  )

# Order families and subtypes by biggest gap within family
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens <- sens %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# Reshape for plotting
sens_long <- sens %>%
  pivot_longer(cols = c(sens_xgb, sens_gpt),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# Plot sleek dots + line with facets
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_line(color = "#999999", linewidth = 0.8) +
  geom_point(aes(fill = model), shape = 21, size = 4, color = "#333333", stroke = 1) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_fill_manual(values = c("XGB" = "steelblue", "GPT" = "firebrick")) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = "Ordered by biggest gap within each family",
    x = "Sensitivity (TP %)",
    y = NULL,
    fill = "Model"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.text.y = element_text(angle = 0, face = "bold")
  )



# VERSION 2C --------------------------------------------------------------


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

# Compute sensitivity & winner
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    sens_xgb = mean(xgb_subtype_match, na.rm = TRUE),
    sens_gpt = mean(gpt_subtype_match, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    family = map_chr(true_subtype, infer_family),
    diff = sens_gpt - sens_xgb
  )

# Order families and subtypes by biggest gap within family
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens <- sens %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# Reshape for plotting
sens_long <- sens %>%
  pivot_longer(cols = c(sens_xgb, sens_gpt),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# Plot sleek dots + line with facets
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  geom_line(color = "#999999", linewidth = 0.8) +
  geom_point(aes(fill = model), shape = 21, size = 4, color = "#333333", stroke = 1) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_fill_manual(values = c("XGB" = "steelblue", "GPT" = "firebrick")) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = "Ordered by biggest gap within each family",
    x = "Sensitivity (TP %)",
    y = NULL,
    fill = "Model"
  ) +
   theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.text.y = element_blank(),   # removes family names
    legend.position = "none"          # removes legend
  )



# VERSION 3 ---------------------------------------------------------------

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

# Compute sensitivity & winner
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    sens_xgb = mean(xgb_subtype_match, na.rm = TRUE),
    sens_gpt = mean(gpt_subtype_match, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    family = map_chr(true_subtype, infer_family),
    diff = sens_gpt - sens_xgb,
    winner = case_when(
      diff > 0 ~ "GPT",
      diff < 0 ~ "XGB",
      TRUE ~ "Tie"
    )
  )

# Family order and sorting by biggest gap
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens <- sens %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# Reshape for plotting
sens_long <- sens %>%
  pivot_longer(cols = c(sens_xgb, sens_gpt),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# Colors
winner_colors <- c("GPT" = "firebrick", "XGB" = "steelblue")

# Plot clean winner-loser version with connecting lines
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  # Connecting lines
  geom_line(color = "#999999", linewidth = 0.8) +
  
  # Winner points (colored)
  geom_point(
    data = sens_long %>% filter(model == winner & winner != "Tie"),
    aes(fill = model),
    shape = 21, size = 4, color = "black", stroke = 1
  ) +
  scale_fill_manual(values = winner_colors, guide = "none") +
  
  # Loser points (small, hollow black)
  geom_point(
    data = sens_long %>% filter(model != winner & winner != "Tie"),
    shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8
  ) +
  
  # Ties as single neutral point
  geom_point(
    data = sens_long %>% filter(winner == "Tie"),
    shape = 21, size = 4, fill = "grey50", color = "black", stroke = 1
  ) +
  
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = "Winner in color; loser as hollow black circle",
    x = "Sensitivity (TP %)",
    y = NULL
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.text.y = element_blank(),  # remove family names
    legend.position = "none"         # remove legend
  )



# VERSION 3B --------------------------------------------------------------
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

# Compute sensitivity & winner
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    sens_xgb = mean(xgb_subtype_match, na.rm = TRUE),
    sens_gpt = mean(gpt_subtype_match, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    family = map_chr(true_subtype, infer_family),
    diff = sens_gpt - sens_xgb,
    winner = case_when(
      diff > 0 ~ "GPT",
      diff < 0 ~ "XGB",
      TRUE ~ "Tie"
    )
  )

# Family order and sorting by biggest gap
family_order <- c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither")

sens <- sens %>%
  mutate(family = factor(family, levels = family_order)) %>%
  group_by(family) %>%
  arrange(desc(abs(diff)), .by_group = TRUE) %>%
  mutate(true_subtype = factor(true_subtype, levels = rev(unique(true_subtype)))) %>%
  ungroup()

# Reshape for plotting
sens_long <- sens %>%
  pivot_longer(cols = c(sens_xgb, sens_gpt),
               names_to = "model", values_to = "sensitivity") %>%
  mutate(model = recode(model,
                        sens_xgb = "XGB",
                        sens_gpt = "GPT"))

# Colors
winner_colors <- c("GPT" = "firebrick", "XGB" = "steelblue")

# Plot
ggplot(sens_long, aes(x = sensitivity, y = true_subtype, group = true_subtype)) +
  # Connecting lines
  geom_line(color = "#999999", linewidth = 0.8) +
  
  # Winner points (colored)
  geom_point(
    data = sens_long %>% filter(model == winner & winner != "Tie"),
    aes(fill = model),
    shape = 21, size = 4, color = "black", stroke = 1
  ) +
  scale_fill_manual(values = winner_colors, guide = "none") +
  
  # Loser points (small, hollow black)
  geom_point(
    data = sens_long %>% filter(model != winner & winner != "Tie"),
    shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8
  ) +
  
  # Ties as single neutral point
  geom_point(
    data = sens_long %>% filter(winner == "Tie"),
    shape = 21, size = 4, fill = "grey50", color = "black", stroke = 1
  ) +
  
  # Winner labels (to the right)
  geom_text(
    data = sens_long %>% filter(model == winner & winner != "Tie"),
    aes(label = scales::percent(sensitivity, accuracy = 1)),
    hjust = -0.3, size = 3, color = "black"
  ) +
  
  # Loser labels (to the left)
  geom_text(
    data = sens_long %>% filter(model != winner & winner != "Tie"),
    aes(label = scales::percent(sensitivity, accuracy = 1)),
    hjust = 1.3, size = 3, color = "black"
  ) +
  
  # Tie labels (to the right)
  geom_text(
    data = sens_long %>% filter(winner == "Tie"),
    aes(label = scales::percent(sensitivity, accuracy = 1)),
    hjust = -0.3, size = 3, color = "black"
  ) +
  
  scale_x_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1.1)) +
  facet_grid(family ~ ., scales = "free_y", space = "free_y") +
  labs(
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = "Winner in color; loser as hollow black circle; sensitivity shown for each",
    x = "Sensitivity (TP %)",
    y = NULL
  ) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.text.y = element_blank(),  # remove family names
    legend.position = "none"         # remove legend
  )



# VERSION 3c --------------------------------------------------------------

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
    label = paste0(correct, "/", total),
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
    hjust = -0.3, size = 3, color = "black"
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
    subtitle = "Winner in color; loser as hollow black circle; counts shown for each",
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
