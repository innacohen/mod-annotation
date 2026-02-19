source("code/_utils.R")


pred_df <- read_csv("data/pipeline/predictions.csv")

names(pred_df)

error_matrix <- pred_df %>%
  transmute(
    file_hash,
    
    XGB =
      xgb_pred_subtype != true_subtype,
    
    `GPT-5.2` =
      gpt_bl_pred_subtype != true_subtype,
    
    `GPT-5.2 + heuristics` =
      gpt_h_pred_subtype != true_subtype,
    
    `GPT-mini` =
      gpt_mini_pred_subtype != true_subtype,
    
    `GPT-mini + heuristics` =
      gpt_mini_h_pred_subtype != true_subtype
  )



upset(
  error_matrix,
  c("XGB", "GPT-5.2", "GPT-5.2 + heuristics", "GPT-mini", "GPT-mini + heuristics"),
  sort_intersections_by = "cardinality"
)


type_correct <- pred_df %>%
  transmute(
    XGB = xgb_pred_type == true_type,
    GPT = gpt_bl_pred_type == true_type,
    `GPT + Heuristics` = gpt_h_pred_type == true_type,
    `GPT-mini` = gpt_mini_pred_type == true_type,
    `GPT-mini + Heuristics` = gpt_mini_h_pred_type == true_type
  ) %>%
  summarise(across(everything(), ~sum(.x, na.rm = TRUE))) %>%
  pivot_longer(
    cols = everything(),
    names_to = "model",
    values_to = "n_correct"
  )


ggplot(type_correct,
       aes(x = reorder(model, n_correct),
           y = n_correct)) +
  geom_col(fill = "#2ca25f", width = 0.65) +
  geom_text(
    aes(label = n_correct),
    hjust = -0.15,          # pushes text slightly outside bar
    size = 3.5
  ) +
  coord_flip() +
  expand_limits(y = max(type_correct$n_correct) * 1.1) +  # room for labels
  labs(
    x = NULL,
    y = "Correct type predictions"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )
