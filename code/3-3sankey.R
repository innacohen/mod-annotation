source("code/_utils.R")

pred_df = read_csv("data/pipeline/predictions.csv") 

pred_df2 = pred_df %>%
  select(file_hash, true_subtype, xgb_pred_subtype, gpt_mini_h_pred_subtype)


df_long <- pred_df2 %>%
  dplyr::select(file_hash,
         true_subtype,
         xgb_pred_subtype,
         gpt_mini_h_pred_subtype) %>%
  pivot_longer(
    cols = c(xgb_pred_subtype, gpt_mini_h_pred_subtype),
    names_to = "model",
    values_to = "predicted_subtype"
  ) %>%
  mutate(
    model = recode(model,
                   xgb_pred_subtype = "XGBoost",
                   gpt_mini_h_pred_subtype = "GPT-mini + heuristics")
  )

flows <- df_long %>%
  count(model, true_subtype, predicted_subtype, name = "n") %>%
  group_by(model) %>%
  mutate(true_subtype = reorder(true_subtype, -n, sum))

flows_err <- flows %>%
  filter(true_subtype != predicted_subtype)

flows_pct_err <- flows_err %>%
  group_by(model) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()


ggplot(
  flows_pct_err,
  aes(axis1 = true_subtype,
      axis2 = predicted_subtype,
      y = pct)
) +
  geom_alluvium(aes(fill = true_subtype), alpha = 0.8) +
  geom_stratum(width = 0.15, fill = "grey90", color = "grey40") +
  geom_text(stat = "stratum",
            aes(label = after_stat(stratum)),
            size = 3) +
  scale_x_discrete(limits = c("True subtype", "Predicted subtype")) +
  facet_wrap(~ model) +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal() +
  theme(panel.grid = element_blank(),
        legend.position = "none",
        axis.title.y = element_blank(),
        axis.text.y = element_blank())


# RESORTED ----------------------------------------------------------------



library(ggplot2)
library(ggalluvial)
library(dplyr)
library(stringr)
library(scales)

# -----------------------------
# 1. Extract ion channel groups
# -----------------------------
flows_pct_err <- flows_pct_err %>%
  mutate(
    true_group = str_extract(true_subtype, "^[IR]\\s*\\w+"),
    pred_group = str_extract(predicted_subtype, "^[IR]\\s*\\w+")
  )

# -----------------------------
# 2. Define biological order
# -----------------------------
group_order <- c(
  "I Na", "I K", "I Ca",       # ion channels
  "R Glutamate", "R GABA",    # receptors
  "I Other", "R Other", "Z Neither"
)

# -----------------------------
# 3. Order subtypes within group (by total flow)
# -----------------------------
true_levels <- flows_pct_err %>%
  group_by(true_subtype, true_group) %>%
  summarise(total = sum(pct), .groups = "drop") %>%
  mutate(true_group = factor(true_group, levels = group_order)) %>%
  arrange(true_group, desc(total)) %>%
  pull(true_subtype)

pred_levels <- flows_pct_err %>%
  group_by(predicted_subtype, pred_group) %>%
  summarise(total = sum(pct), .groups = "drop") %>%
  mutate(pred_group = factor(pred_group, levels = group_order)) %>%
  arrange(pred_group, desc(total)) %>%
  pull(predicted_subtype)

# -----------------------------
# 4. Align both axes (optional but recommended)
# -----------------------------
all_levels <- union(true_levels, pred_levels)

flows_pct_err <- flows_pct_err %>%
  mutate(
    true_subtype = factor(true_subtype, levels = all_levels),
    predicted_subtype = factor(predicted_subtype, levels = all_levels)
  )

# -----------------------------
# 5. Plot Sankey
# -----------------------------
ggplot(
  flows_pct_err,
  aes(axis1 = true_subtype,
      axis2 = predicted_subtype,
      y = pct)
) +
  geom_alluvium(aes(fill = true_subtype), alpha = 0.8) +
  geom_stratum(width = 0.15, fill = "grey90", color = "grey40") +
  geom_text(stat = "stratum",
            aes(label = after_stat(stratum)),
            size = 3) +
  scale_x_discrete(limits = c("True subtype", "Predicted subtype")) +
  facet_wrap(~ model) +
  scale_y_continuous(labels = percent) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    legend.position = "none",
    axis.title.y = element_blank(),
    axis.text.y = element_blank()
  )
