source("code/_utils.R")

library(dplyr)
library(caret)
library(purrr)

compute_sensitivity <- function(df, pred_col, model_name) {
  
  df2 <- df %>%
    filter(!is.na(true_subtype)) %>%
    mutate(
      truth = factor(true_subtype),
      pred  = factor({{ pred_col }}, levels = levels(truth))
    )
  
  cm <- caret::confusionMatrix(df2$pred, df2$truth)
  
  tibble(
    true_subtype = rownames(cm$byClass),
    sensitivity  = cm$byClass[, "Sensitivity"],
    model = model_name
  ) %>%
    mutate(
      true_subtype = sub("^Class:\\s*", "", true_subtype)
    )
}

# ------------------------------------------------------------------
# IMPORT DATA
# ------------------------------------------------------------------
library(tidyverse)
pred_df <- read_csv("data/pipeline/predictions.csv")

# Total N per true subtype (shared across both figures)
count_df <- pred_df %>%
  count(true_subtype, name = "n_total")

# ------------------------------------------------------------------
# GPT 5.2
# ------------------------------------------------------------------
sens_df_gpt <- bind_rows(
  compute_sensitivity(pred_df, pred_df$xgb_pred_subtype,     "XGB"),
  compute_sensitivity(pred_df, pred_df$gpt_bl_pred_subtype, "GPT"),
  compute_sensitivity(pred_df, pred_df$gpt_h_pred_subtype,  "GPT_H")
)


plot_df_gpt <- sens_df_gpt %>%
  left_join(
    sens_df_gpt %>% filter(model == "XGB") %>%
      select(true_subtype, xgb = tp),
    by = "true_subtype"
  ) %>%
  left_join(
    sens_df_gpt %>% filter(model == "GPT") %>%
      select(true_subtype, gpt = tp),
    by = "true_subtype"
  ) %>%
  mutate(
    true_subtype = fct_reorder(true_subtype, xgb),
    
    # PRIORITY:
    # 1) Tie with XGB  -> BLACK
    # 2) GPT ties GPT_H (not XGB) -> GREY
    # 3) Otherwise model color
    
    plot_model = case_when(
      model == "XGB" ~ "XGB",
      
      tp == xgb ~ "TIE_XGB",
      
      model == "GPT_H" & tp == gpt ~ "GPT_H_SAME",
      
      TRUE ~ model
    )
  ) %>%
  left_join(count_df, by = "true_subtype")

# Y labels with counts
y_labels_gpt <- plot_df_gpt %>%
  distinct(true_subtype, n_total) %>%
  mutate(label = paste0(as.character(true_subtype), ", n=", n_total)) %>%
  { setNames(.$label, .$true_subtype) }

colors_gpt <- c(
  XGB        = "#FFA273",
  GPT        = "#1F77B4",
  GPT_H      = "#7B6FD6",
  GPT_H_SAME = "grey60",
  TIE_XGB    = "black"
)

fig_gpt <- ggplot(plot_df_gpt, aes(y = fct_rev(true_subtype))) +
  geom_segment(
    data = plot_df_gpt %>% filter(model != "XGB"),
    aes(x = xgb, xend = tp, yend = fct_rev(true_subtype)),
    color = "grey70",
    linewidth = 0.7
  ) +
  geom_point(aes(x = tp, color = plot_model), size = 3) +
  scale_color_manual(
    values = colors_gpt,
    breaks = c("XGB", "GPT", "GPT_H", "GPT_H_SAME", "TIE_XGB"),
    labels = c("XGB", "GPT", "GPT + heuristics", "GPT ties GPT+heur", "Tie with XGB"),
    name = "Model"
  ) +
  scale_x_continuous(limits = c(0, 100), labels = function(x) paste0(x, "%")) +
  scale_y_discrete(labels = y_labels_gpt) +
  labs(title = "A. GPT 5.2 TPR", x = "True Positive (%)", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 11),
    legend.position = "none"
  )

fig_gpt


# ------------------------------------------------------------------
# GPT MINI
# ------------------------------------------------------------------

plot_df_mini <- plot_df_mini %>%
  left_join(count_df, by = "true_subtype")


y_labels_mini <- plot_df_mini %>%
  distinct(true_subtype, n_total) %>%
  mutate(label = paste0(as.character(true_subtype), ", n=", n_total)) %>%
  { setNames(.$label, .$true_subtype) }

fig_gpt_mini <- ggplot(plot_df_mini, aes(y = fct_rev(true_subtype))) +
  geom_segment(
    data = plot_df_mini %>% filter(model != "XGB"),
    aes(x = xgb, xend = tp, yend = fct_rev(true_subtype)),
    color = "grey70",
    linewidth = 0.7
  ) +
  geom_point(aes(x = tp, color = plot_model), size = 3) +
  scale_color_manual(
    values = colors_mini,
    breaks = c("XGB", "GPT_MINI", "GPT_MINI_H", "GPT_MINI_H_SAME"),
    labels = c("XGB", "GPT-mini", "GPT-mini + heuristics", "GPT-mini tie"),
    name = "Model"
  ) +
  scale_x_continuous(limits = c(0, 100), labels = function(x) paste0(x, "%")) +
  scale_y_discrete(labels = y_labels_mini) +
  labs(title = "C. GPT mini TPR", x = "True Positive (%)", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 11),
    legend.position = "none"
  )

fig_gpt_mini

# ------------------------------------------------------------------
# PANEL
# ------------------------------------------------------------------

fig_panel <- fig_gpt + fig_gpt_mini +
  plot_layout(ncol = 2, guides = "collect") &
  theme(legend.position = "none")

fig_panel

# FP ----------------------------------------------------------------------


fp_df_gpt <- bind_rows(
  compute_fp(pred_df, pred_df$xgb_pred_subtype,    "XGB"),
  compute_fp(pred_df, pred_df$gpt_bl_pred_subtype, "GPT"),
  compute_fp(pred_df, pred_df$gpt_h_pred_subtype,  "GPT_H")
)

plot_fp_gpt <- fp_df_gpt %>%
  left_join(
    fp_df_gpt %>% filter(model == "XGB") %>%
      select(true_subtype, xgb = fp),
    by = "true_subtype"
  ) %>%
  left_join(
    fp_df_gpt %>% filter(model == "GPT") %>%
      select(true_subtype, gpt = fp),
    by = "true_subtype"
  ) %>%
  mutate(
    true_subtype = fct_reorder(true_subtype, xgb),
    plot_model = case_when(
      model == "GPT_H" & fp == gpt ~ "GPT_H_SAME",
      TRUE                         ~ model
    )
  )

fig_gpt_fp <- ggplot(plot_fp_gpt, aes(y = fct_rev(true_subtype))) +
  
  geom_segment(
    data = plot_fp_gpt %>% filter(model != "XGB"),
    aes(x = xgb, xend = fp, yend = fct_rev(true_subtype)),
    color = "grey70",
    linewidth = 0.7,
    lineend = "butt"
  ) +
  
  geom_point(
    aes(x = fp, color = plot_model),
    size = 3
  ) +
  
  scale_color_manual(
    values = colors_gpt,
    breaks = c("XGB", "GPT", "GPT_H", "GPT_H_SAME"),
    labels = c(
      "XGB",
      "GPT",
      "GPT + heuristics",
      "GPT tie (heuristics = GPT)"
    ),
    name = "Model"
  ) +
  
  scale_x_continuous(
    limits = c(0, 100),
    labels = function(x) paste0(x, "%")
  ) +
  
  labs(
    title = "B. GPT 5.2 FPR", 
    x = "False Positive (%)",
    y = NULL
  ) +
  
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 11),
    legend.position = "none"
  )

fp_df_mini <- bind_rows(
  compute_fp(pred_df, pred_df$xgb_pred_subtype,        "XGB"),
  compute_fp(pred_df, pred_df$gpt_mini_pred_subtype,   "GPT_MINI"),
  compute_fp(pred_df, pred_df$gpt_mini_h_pred_subtype, "GPT_MINI_H")
)

plot_fp_mini <- fp_df_mini %>%
  left_join(
    fp_df_mini %>% filter(model == "XGB") %>%
      select(true_subtype, xgb = fp),
    by = "true_subtype"
  ) %>%
  left_join(
    fp_df_mini %>% filter(model == "GPT_MINI") %>%
      select(true_subtype, gpt_mini = fp),
    by = "true_subtype"
  ) %>%
  mutate(
    true_subtype = fct_reorder(true_subtype, xgb),
    plot_model = case_when(
      model == "GPT_MINI_H" & fp == gpt_mini ~ "GPT_MINI_H_SAME",
      TRUE                                   ~ model
    )
  )

fig_gpt_mini_fp <- ggplot(plot_fp_mini, aes(y = fct_rev(true_subtype))) +
  
  geom_segment(
    data = plot_fp_mini %>% filter(model != "XGB"),
    aes(x = xgb, xend = fp, yend = fct_rev(true_subtype)),
    color = "grey70",
    linewidth = 0.7,
    lineend = "butt"
  ) +
  
  geom_point(
    aes(x = fp, color = plot_model),
    size = 3
  ) +
  
  scale_color_manual(
    values = colors_mini,
    breaks = c("XGB", "GPT_MINI", "GPT_MINI_H", "GPT_MINI_H_SAME"),
    labels = c(
      "XGB",
      "GPT-mini",
      "GPT-mini + heuristics",
      "GPT-mini tie (heuristics = GPT-mini)"
    ),
    name = "Model"
  ) +
  
  scale_x_continuous(
    limits = c(0, 100),
    labels = function(x) paste0(x, "%")
  ) +
  
  labs(
    title = "D. GPT mini FPR",
    x = "False Positive (%)",
    y = NULL
  ) +
  
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 11),
    legend.position = "none"
  )



fig_full_panel <- fig_gpt + fig_gpt_fp + fig_gpt_mini + fig_gpt_mini_fp +
  plot_layout(
    ncol = 2,
    guides = "collect"
  ) &
  theme(
    legend.position = "none"
  )

fig_full_panel

