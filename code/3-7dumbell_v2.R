# ================================================================
# Libraries
# ================================================================

library(tidyverse)
library(forcats)
library(caret)
library(scales)

# ================================================================
# Color palette
# ================================================================

colors_gpt <- c(
  XGB        = "#FFA273",
  GPT        = "#1F77B4",
  GPT_H      = "#7B6FD6",
  GPT_H_SAME = "grey60",
  TIE_XGB    = "black"
)

# ================================================================
# Sensitivity function
# ================================================================

compute_sensitivity <- function(df, pred_col, model_name) {
  
  df2 <- df %>%
    filter(!is.na(true_subtype)) %>%
    mutate(
      truth = factor(true_subtype),
      pred  = factor({{ pred_col }}, levels = levels(truth))
    )
  
  cm <- confusionMatrix(df2$pred, df2$truth)
  
  tibble(
    true_subtype = rownames(cm$byClass),
    sensitivity  = cm$byClass[, "Sensitivity"],
    model = model_name
  ) %>%
    mutate(
      true_subtype = sub("^Class:\\s*", "", true_subtype)
    )
}

# ================================================================
# Import data
# ================================================================

pred_df <- read_csv("data/pipeline/predictions.csv")

pred_df2 <- pred_df %>%
  select(
    file_hash,
    true_subtype,
    xgb_pred_subtype,
    gpt_mini_pred_subtype,
    gpt_mini_h_pred_subtype
  )

# ------------------------------------------------
# Total N per true subtype (for y-axis labels)
# ------------------------------------------------

count_df <- pred_df2 %>%
  filter(!is.na(true_subtype)) %>%
  count(true_subtype, name = "n_total") %>%
  mutate(
    subtype_label = paste0(true_subtype, ", n = ", n_total)
  )

# ================================================================
# Compute sensitivities (long format)
# ================================================================

sens_xgb   <- compute_sensitivity(pred_df2, xgb_pred_subtype, "XGB")
sens_gpt   <- compute_sensitivity(pred_df2, gpt_mini_pred_subtype, "GPT")
sens_gpt_h <- compute_sensitivity(pred_df2, gpt_mini_h_pred_subtype, "GPT_H")

sens_df <- bind_rows(sens_xgb, sens_gpt, sens_gpt_h)


# Find GPT vs GPT_H ties per subtype
tie_df <- sens_df %>%
  pivot_wider(names_from = model, values_from = sensitivity) %>%
  mutate(
    three_way_tie =
      abs(XGB - GPT)   < 1e-8 &
      abs(XGB - GPT_H) < 1e-8,
    
    gpt_tie =
      abs(GPT - GPT_H) < 1e-8 & !three_way_tie
  ) %>%
  select(true_subtype, three_way_tie, gpt_tie)


# Join back to long dataframe
sens_df2 <- sens_df %>%
  left_join(tie_df, by = "true_subtype") %>%
  left_join(count_df, by = "true_subtype") %>%
  mutate(
    plot_model = case_when(
      three_way_tie                          ~ "TIE_XGB",
      gpt_tie & model %in% c("GPT","GPT_H") ~ "GPT_H_SAME",
      TRUE                                  ~ model
    )
  )
# ================================================================
# Dumbbell ranges (min -> max per subtype)
# ================================================================

range_df <- sens_df2 %>%
  group_by(subtype_label) %>%
  summarise(
    xmin = min(sensitivity, na.rm = TRUE),
    xmax = max(sensitivity, na.rm = TRUE),
    .groups = "drop"
  )

ggplot(
  sens_df2,
  aes(
    x = sensitivity,
    y = fct_reorder(subtype_label, sensitivity)
  )
) +
  
  # ---------------------------------------
# Dumbbell line: min -> max per subtype
# ---------------------------------------
geom_segment(
  data = range_df,
  aes(
    x = xmin,
    xend = xmax,
    y = subtype_label,
    yend = subtype_label
  ),
  inherit.aes = FALSE,
  color = "grey75",
  linewidth = 1
) +
  
  # ---------------------------------------
# Points
# ---------------------------------------
geom_point(
  aes(color = plot_model),
  size = 3,
  position = position_nudge(
    x = ifelse(sens_df2$model == "GPT",   0.002,
               ifelse(sens_df2$model == "GPT_H", -0.002, 0))
  )
) +
  
  # ---------------------------------------
# Colors
# ---------------------------------------
scale_color_manual(values = colors_gpt) +
  
  # ---------------------------------------
# X axis
# ---------------------------------------
scale_x_continuous(
  labels = scales::percent_format(accuracy = 1),
  limits = c(0, 1)
) +
  
  # ---------------------------------------
# Labels
# ---------------------------------------
labs(
  x = "Sensitivity",
  y = NULL,
  title = "Subtype-Level Sensitivity"
) +
  
  # ---------------------------------------
# Theme
# ---------------------------------------
theme_minimal(base_size = 13) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.title = element_blank()
  )
