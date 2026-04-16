source("code/_utils.R")
pred_df <- read_csv("data/pipeline/predictions.csv")

# ---------------------------------------------------------
# Define models (now including XGB)
# ---------------------------------------------------------
models <- c(
  "XGB"                  = "xgb_pred_subtype",
  "GPT-5.2"              = "gpt_bl_pred_subtype",
  "GPT-5.2 + heuristics" = "gpt_h_pred_subtype",
  "GPT-mini"             = "gpt_mini_pred_subtype",
  "GPT-mini + heuristics" = "gpt_mini_h_pred_subtype"
)

# ---------------------------------------------------------
# Build correctness matrix
# ---------------------------------------------------------
correct_mat <- pred_df %>%
  transmute(
    file_hash,
    across(all_of(models), ~ .x == true_subtype)
  )

# ---------------------------------------------------------
# Compute rescue percentages
# ---------------------------------------------------------
rescue_matrix <- expand_grid(
  from = names(models),
  to   = names(models)
) %>%
  rowwise() %>%
  mutate(
    rescue_pct = mean(
      (!correct_mat[[from]]) & correct_mat[[to]],
      na.rm = TRUE
    ) * 100
  ) %>%
  ungroup()

# ---------------------------------------------------------
# Plot heatmap
# ---------------------------------------------------------
ggplot(rescue_matrix, aes(to, from, fill = rescue_pct)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.1f%%", rescue_pct)), size = 3) +
  scale_fill_gradient(low = "white", high = "#1F77B4") +
  labs(
    x = "Model providing correct classification",
    y = "Model making error",
    fill = "% rescued",
    title = "Pairwise Model Error Recovery"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank()
  )