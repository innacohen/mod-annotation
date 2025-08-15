library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)

df <- read_csv("model_eval_unified.csv", show_col_types = FALSE)

preds <- df %>% filter(section == "predictions")
fi    <- df %>% filter(section == "feature_importance")

# --- 1) Confusion matrices (examples) ---
# Type (XGB)
cm_type_xgb <- with(preds, table(True = true_type, Pred = pred_type_xgb))
# Row-normalized
cm_type_xgb_row <- prop.table(cm_type_xgb, margin = 1)

# Subtype (GPT)
cm_sub_gpt <- with(preds, table(True = true_subtype, Pred = gpt_pred_subtype))
cm_sub_gpt_row <- prop.table(cm_sub_gpt, margin = 1)

# Heatmap plot helper
plot_cm <- function(cm, title) {
  as.data.frame(cm) %>%
    ggplot(aes(x = Pred, y = True, fill = Freq)) +
    geom_tile() +
    geom_text(aes(label = ifelse(is.na(Freq), "", round(Freq, 2)))) +
    scale_fill_continuous() +
    labs(title = title, x = "Predicted", y = "True") +
    theme(axis.text.x = element_text(angle = 90, hjust = 1))
}

# Counts
plot_cm(cm_type_xgb, "TYPE Confusion (XGB, counts)")
# Row-normalized
plot_cm(cm_type_xgb_row, "TYPE Confusion (XGB, row-normalized)")

# --- 2) Feature importance (top 15 by gain) ---
fi_top <- fi %>%
  arrange(desc(imp_gain)) %>%
  slice_head(n = 15)

ggplot(fi_top, aes(x = reorder(feature, imp_gain), y = imp_gain)) +
  geom_col() +
  coord_flip() +
  labs(title = "Top 15 Features by Gain (XGB subtype model)",
       x = "Feature", y = "Gain")

# --- 3) Sensitivity by subtype (TP/total) ---
sens_subtype <- preds %>%
  group_by(true_subtype, family) %>%
  summarise(
    n = n(),
    tp_xgb = sum(true_subtype == pred_subtype_xgb, na.rm = TRUE),
    tp_gpt = sum(true_subtype == gpt_pred_subtype, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    sens_xgb = tp_xgb / n,
    sens_gpt = tp_gpt / n
  )

# Faceted dumbbell-style comparison (optional)
sens_long <- sens_subtype %>%
  select(true_subtype, family, sens_xgb, sens_gpt) %>%
  pivot_longer(cols = starts_with("sens_"),
               names_to = "model", values_to = "sensitivity")

ggplot(sens_long,
       aes(x = sensitivity * 100, y = reorder(true_subtype, sensitivity),
           color = model)) +
  geom_point() +
  labs(title = "Subtype Sensitivity (TP%)",
       x = "Sensitivity (%)", y = "Subtype") +
  facet_wrap(~ family, scales = "free_y") +
  theme(legend.position = "bottom")

# --- 4) Sensitivity by TYPE (same idea) ---
sens_type <- preds %>%
  group_by(true_type) %>%
  summarise(
    n = n(),
    tp_xgb = sum(true_type == pred_type_xgb, na.rm = TRUE),
    tp_gpt = sum(true_type == gpt_pred_type, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    sens_xgb = tp_xgb / n,
    sens_gpt = tp_gpt / n
  )

# Quick bar comparison for TYPE
sens_type_long <- sens_type %>%
  select(true_type, sens_xgb, sens_gpt) %>%
  pivot_longer(cols = starts_with("sens_"),
               names_to = "model", values_to = "sensitivity")

ggplot(sens_type_long, aes(x = true_type, y = sensitivity, fill = model)) +
  geom_col(position = position_dodge(width = 0.7)) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Type Sensitivity by Model", x = "Type", y = "Sensitivity") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
