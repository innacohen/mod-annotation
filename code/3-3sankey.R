library(ggplot2)
library(ggalluvial)
library(dplyr)
library(stringr)
library(scales)
library(readr)

source("code/_utils.R")
pred_df <- read_csv("data/pipeline/predictions.csv")

# ── wrangle ───────────────────────────────────────────────────────────────────
pred_df2 <- pred_df %>%
  select(file_hash, true_subtype, xgb_pred_subtype, gpt_mini_h_pred_subtype)

df_long <- pred_df2 %>%
  pivot_longer(
    cols = c(xgb_pred_subtype, gpt_mini_h_pred_subtype),
    names_to = "model",
    values_to = "predicted_subtype"
  ) %>%
  mutate(model = recode(model,
                        xgb_pred_subtype       = "XGBoost",
                        gpt_mini_h_pred_subtype = "GPT-mini + heuristics"
  ))

flows <- df_long %>%
  count(model, true_subtype, predicted_subtype, name = "n")

flows_err <- flows %>%
  filter(true_subtype != predicted_subtype)

flows_pct_err <- flows_err %>%
  group_by(model) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

# ── alphabetical factor levels (shared across both axes) ─────────────────────
all_levels <- sort(union(
  unique(flows_pct_err$true_subtype),
  unique(flows_pct_err$predicted_subtype)
))

flows_pct_err <- flows_pct_err %>%
  mutate(
    true_subtype      = factor(true_subtype,      levels = all_levels),
    predicted_subtype = factor(predicted_subtype, levels = all_levels)
  )

# ── colour palette (one per true subtype) ────────────────────────────────────
n_colors  <- length(all_levels)
pal       <- setNames(hue_pal()(n_colors), all_levels)

# ── plot ──────────────────────────────────────────────────────────────────────
p = ggplot(
  flows_pct_err,
  aes(axis1 = true_subtype,
      axis2 = predicted_subtype,
      y     = pct)
) +
  geom_alluvium(aes(fill = true_subtype), alpha = 0.75, width = 1/4) +
  # FIX 1: wider strata so labels don't overflow
  geom_stratum(width = 1/4, fill = "grey92", color = "grey50", linewidth = 0.3) +
  # FIX 2: geom_label clips text inside the box; label.size = 0 removes border
  geom_label(
    stat       = "stratum",
    aes(label  = after_stat(stratum)),
    size       = 2.6,
    label.size = 0,          # no border around label
    fill       = "grey92",   # match stratum fill so it looks seamless
    label.padding = unit(0.15, "lines")
  ) +
  scale_x_discrete(limits = c("True subtype", "Predicted subtype"),
                   expand = c(0.15, 0.15)) +  # FIX 3: breathing room at edges
  scale_fill_manual(values = pal) +
  facet_wrap(~ model) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  theme_minimal(base_size = 14) +
  theme(
    panel.grid    = element_blank(),
    legend.position = "none",
    axis.title.y  = element_blank(),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    strip.text    = element_text(size = 14, face = "bold"),
    axis.text.x =  element_text(size = 14, face = "bold")
  )
ggsave(
  filename = "figures/sankey_errors.png",
  plot     = p,
  width    = 17,
  height   = 10,
  dpi      = 300,
  bg       = "white"
)



# Version 2 ---------------------------------------------------------------

# ── use ALL flows (correct + incorrect) ──────────────────────────────────────
flows_pct_all <- flows %>%
  group_by(model) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

# ── alphabetical factor levels ────────────────────────────────────────────────
all_levels <- sort(union(
  unique(flows_pct_all$true_subtype),
  unique(flows_pct_all$predicted_subtype)
))

flows_pct_all <- flows_pct_all %>%
  mutate(
    true_subtype      = factor(true_subtype,      levels = all_levels),
    predicted_subtype = factor(predicted_subtype, levels = all_levels)
  )

# ── colour palette ────────────────────────────────────────────────────────────
n_colors <- length(all_levels)
pal      <- setNames(hue_pal()(n_colors), all_levels)

# ── plot ──────────────────────────────────────────────────────────────────────
ggplot(
  flows_pct_all,
  aes(axis1 = true_subtype,
      axis2 = predicted_subtype,
      y     = pct)
) +
  geom_alluvium(aes(fill = true_subtype), alpha = 0.75, width = 1/4) +
  geom_stratum(width = 1/4, fill = "grey92", color = "grey50", linewidth = 0.3) +
  geom_label(
    stat          = "stratum",
    aes(label     = after_stat(stratum)),
    size          = 2.6,
    label.size    = 0,
    fill          = "grey92",
    label.padding = unit(0.15, "lines")
  ) +
  scale_x_discrete(limits = c("True subtype", "Predicted subtype"),
                   expand = c(0.15, 0.15)) +
  scale_fill_manual(values = pal) +
  facet_wrap(~ model) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid      = element_blank(),
    legend.position = "none",
    axis.title.y    = element_blank(),
    axis.text.y     = element_blank(),
    axis.ticks.y    = element_blank(),
    strip.text      = element_text(size = 11, face = "bold")
  )
