source("code/_utils.R")

pred_df <- read_csv("data/pipeline/predictions.csv")


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
