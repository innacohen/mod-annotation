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
  flows_err,
  aes(axis1 = true_subtype,
      axis2 = predicted_subtype,
      y = n)
) +
  geom_alluvium(aes(fill = true_subtype), alpha = 0.8) +
  geom_stratum(width = 0.15, fill = "grey90", color = "grey40") +
  geom_text(stat = "stratum",
            aes(label = after_stat(stratum)),
            size = 3) +
  scale_x_discrete(limits = c("True subtype", "Predicted subtype")) +
  facet_wrap(~ model) +
  theme_minimal() +
  theme(panel.grid = element_blank(),
        legend.position = "none")


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

