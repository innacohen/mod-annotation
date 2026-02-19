library(tidyverse)
library(forcats)

#-----------------------------
# 1. Load data
#-----------------------------
pred_df = read_csv("data/pipeline/predictions.csv") 

pred_df2 = pred_df %>%
  select(file_hash, true_subtype,
         xgb_pred_subtype,
         gpt_mini_pred_subtype,
         gpt_mini_h_pred_subtype)

#-----------------------------
# 2. Convert to long format
#-----------------------------
long_df <- pred_df2 %>%
  pivot_longer(
    cols = c(xgb_pred_subtype,
             gpt_mini_pred_subtype,
             gpt_mini_h_pred_subtype),
    names_to = "model",
    values_to = "predicted_subtype"
  ) %>%
  mutate(
    model = recode(model,
                   "xgb_pred_subtype" = "XGB",
                   "gpt_mini_pred_subtype" = "GPT",
                   "gpt_mini_h_pred_subtype" = "GPT+Heuristics")
  )

#-----------------------------
# 3. Calculate sensitivity per subtype per model
#-----------------------------
sens_df <- long_df %>%
  group_by(true_subtype, model) %>%
  summarise(
    sensitivity = mean(predicted_subtype == true_subtype, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

#-----------------------------
# 4. Create dumbbell base (min/max per subtype)
#-----------------------------
range_df <- sens_df %>%
  group_by(true_subtype) %>%
  summarise(
    min_sens = min(sensitivity),
    max_sens = max(sensitivity),
    .groups = "drop"
  )

# Order subtypes by average sensitivity (optional but nicer)
order_levels <- sens_df %>%
  group_by(true_subtype) %>%
  summarise(avg = mean(sensitivity), .groups = "drop") %>%
  arrange(avg) %>%
  pull(true_subtype)

sens_df$true_subtype <- factor(sens_df$true_subtype, levels = order_levels)
range_df$true_subtype <- factor(range_df$true_subtype, levels = order_levels)

#-----------------------------
# 5. Plot
#-----------------------------
ggplot() +
  
  # Dumbbell segment
  geom_segment(data = range_df,
               aes(x = min_sens,
                   xend = max_sens,
                   y = true_subtype,
                   yend = true_subtype),
               color = "grey70",
               linewidth = 1.2) +
  
  # Model points
  geom_point(data = sens_df,
             aes(x = sensitivity,
                 y = true_subtype,
                 color = model),
             size = 3) +
  
  scale_color_manual(values = c(
    "XGB" = "orange",
    "GPT" = "blue",
    "GPT+Heuristics" = "purple"
  )) +
  
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  
  labs(
    x = "Sensitivity",
    y = "True Subtype",
    color = "Model"
  ) +
  
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.major.y = element_blank(),
    legend.position = "right"
  )
