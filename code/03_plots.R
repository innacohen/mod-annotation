library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)

setwd("~/palmer_scratch/mod-extract/code")
df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

View(df)
names(df)

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggalt)  # for geom_dumbbell

# Read your data
df <- read_csv("predictions_combined.csv", show_col_types = FALSE)

# Compute subtype sensitivity for each model
sens <- df %>%
  group_by(true_subtype) %>%
  summarise(
    total = n(),
    sens_xgb = sum(xgb_subtype_match, na.rm = TRUE) / total,
    sens_gpt = sum(gpt_subtype_match, na.rm = TRUE) / total,
    .groups = "drop"
  )

# Create dumbbell plot
ggplot(sens, aes(y = reorder(true_subtype, sens_xgb))) +
  geom_dumbbell(
    aes(x = sens_xgb, xend = sens_gpt),
    colour = "grey70", size = 1.2,
    colour_x = "dimgray", colour_xend = "lightgray"
  ) +
  geom_text(aes(x = sens_xgb, label = scales::percent(sens_xgb, accuracy = 0.1)),
            vjust = -0.5, colour = "dimgray", size = 3) +
  geom_text(aes(x = sens_gpt, label = scales::percent(sens_gpt, accuracy = 0.1)),
            vjust = 1.5, colour = "black", size = 3) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    x = "Sensitivity (TP %)",
    y = "Subtype",
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = "Dumbbell plot comparing true positive rates"
  ) +
  theme_minimal()
