
library(ggplot2)
library(dplyr)
library(tidyverse)

df_long = read_csv("project/mod-extract/data/combined_metrics_long.csv")

# Assuming your data looks like this:
# df_long: Subtype | Family | Model | `TP %` | TP | n

ggplot(df_long, aes(x = Subtype, y = `TP %`, fill = Model)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  geom_text(
    aes(label = paste0(TP, " / ", n)),
    position = position_dodge(width = 0.9),
    vjust = -0.3, # nudges text slightly above bar
    size = 3.5
  ) +
  facet_wrap(~Family, scales = "free_x", ncol = 2) +
  theme_bw() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.margin = margin(t = 20, r = 20, b = 60, l = 20),
    strip.text = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  ) +
  labs(
    title = "True Positive % by Subtype and Ion Family (XGBoost vs GPT)",
    x = "Subtype",
    y = "True Positive %"
  ) +
  scale_fill_manual(values = c("GPT" = "#e76f51", "XGBoost" = "#66c2a5")) # optional custom colors
