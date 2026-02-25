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

upset(
  error_matrix,
  c("XGB", "GPT-5.2", "GPT-5.2 + heuristics", "GPT-mini", "GPT-mini + heuristics"),
  sort_intersections_by = "cardinality",
  main.bar.color = "red",       # Colors the vertical intersection bars
  sets.bar.color = "firebrick"   # Colors the horizontal set size bars
)

source("code/_utils.R")
pred_df <- read_csv("data/pipeline/predictions.csv")

#---------------------------------------
# Build logical error matrix
#---------------------------------------
error_matrix <- pred_df %>%
  transmute(
    file_hash,
    XGB                    = xgb_pred_subtype != true_subtype,
    `GPT-5.2`              = gpt_bl_pred_subtype != true_subtype,
    `GPT-5.2 + heuristics` = gpt_h_pred_subtype != true_subtype,
    `GPT-mini`             = gpt_mini_pred_subtype != true_subtype,
    `GPT-mini + heuristics`= gpt_mini_h_pred_subtype != true_subtype
  )

sets <- c(
  "XGB",
  "GPT-5.2",
  "GPT-5.2 + heuristics",
  "GPT-mini",
  "GPT-mini + heuristics"
)




# COLORFUL UPSET ----------------------------------------------------------

source("code/_utils.R")
pred_df <- read_csv("data/pipeline/predictions.csv")

#---------------------------------------
# Build logical error matrix
#---------------------------------------
error_matrix <- pred_df %>%
  transmute(
    file_hash,
    XGB                    = xgb_pred_subtype != true_subtype,
    `GPT-5.2`              = gpt_bl_pred_subtype != true_subtype,
    `GPT-5.2 + heuristics` = gpt_h_pred_subtype != true_subtype,
    `GPT-mini`             = gpt_mini_pred_subtype != true_subtype,
    `GPT-mini + heuristics`= gpt_mini_h_pred_subtype != true_subtype
  )

sets <- c(
  "XGB",
  "GPT-5.2",
  "GPT-5.2 + heuristics",
  "GPT-mini",
  "GPT-mini + heuristics"
)

#---------------------------------------
# UpSet plot
#---------------------------------------
# Install if needed:
# install.packages("ComplexUpset")
library(ComplexUpset)
library(ggplot2)

sets <- c(
  "XGB",
  "GPT-5.2",
  "GPT-5.2 + heuristics",
  "GPT-mini",
  "GPT-mini + heuristics"
)

# ComplexUpset expects TRUE/FALSE columns and a character vector of set names
upset(
  data      = as.data.frame(error_matrix),   # must be a data.frame, not tibble
  intersect = sets,
  
  # --- bar chart on top ---
  base_annotations = list(
    "Intersection size" = intersection_size(
      counts   = TRUE,
      mapping  = aes(fill = "bar")
    ) +
      scale_fill_manual(values = c(bar = "#E05C5C"), guide = "none") +
      ylab("# errors in intersection")
  ),
  
  # --- set-size bars on the left ---
  set_sizes = (
    upset_set_size(
      geom = geom_bar(fill = "#4A90D9")
    ) +
      ylab("Total errors per model")
  ),
  
  # --- dot-and-line matrix ---
  matrix = intersection_matrix(
    geom   = geom_point(size = 3.5, color = "#333333"),
    segment = geom_segment(color = "#333333", linewidth = 0.8)
  ),
  
  # --- ordering ---
  sort_intersections   = "descending",  # largest intersections first
  sort_intersections_by = "cardinality",
  sort_sets            = FALSE,          # keep your manual set order
  
  # --- aesthetics ---
  width_ratio = 0.25,
  height_ratio = 0.6,
  themes = upset_modify_themes(
    list(
      "intersections_matrix" = theme(
        text = element_text(family = "sans", size = 11)
      ),
      "overall_sizes" = theme(
        axis.text.x = element_text(angle = 45, hjust = 1)
      )
    )
  )
) +
  labs(
    title    = "Overlap in prediction errors across models",
    subtitle = "Each bar = cases where exactly that combination of models was wrong"
  ) +
  theme(
    plot.title    = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 10, color = "grey40")
  )



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





# TYPE CORRECT ------------------------------------------------------------




type_correct <- pred_df %>%
  transmute(
    XGB = xgb_pred_type == true_type,
    `GPT-5.2` = gpt_bl_pred_type == true_type,
    `GPT-5.2 + Heuristics` = gpt_h_pred_type == true_type,
    `GPT-mini` = gpt_mini_pred_type == true_type,
    `GPT-mini + Heuristics` = gpt_mini_h_pred_type == true_type
  ) %>%
  summarise(across(everything(), ~sum(.x, na.rm = TRUE))) %>%
  pivot_longer(
    cols = everything(),
    names_to = "model",
    values_to = "n_correct"
  ) %>%
  mutate(
    model = factor(
      model,
      levels = c(
        "XGB",
        "GPT-mini",
        "GPT-5.2",
        "GPT-mini + Heuristics",
        "GPT-5.2 + Heuristics"
      )
    )
  )

type_correct <- type_correct %>%
  mutate(
    model = factor(
      model,
      levels = rev(c(
        "XGB",
        "GPT-mini",
        "GPT-5.2",
        "GPT-mini + Heuristics",
        "GPT-5.2 + Heuristics"
      ))
    )
  )


ggplot(type_correct,
       aes(x = model, y = n_correct)) +
  geom_col(fill = "#D9D9D9", width = 0.65) +
  geom_text(
    aes(label = n_correct),
    hjust = -0.15,
    size = 3.5
  ) +
  coord_flip() +
  expand_limits(y = max(type_correct$n_correct) * 1.1) +
  labs(
    x = NULL,
    y = "Correct type predictions"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )
#595959
##D9D9D9

ggplot(type_correct,
       aes(x = n_correct,
           y = reorder(model, n_correct))) +
  geom_point(size = 4, color = "#D9D9D9") +
  geom_text(aes(label = n_correct),
            hjust = -0.5,
            size = 3.5) +
  scale_x_continuous(limits = c(225, 250)) +
  labs(x = "Correct type predictions",
       y = NULL) +
  theme_minimal()





library(ggplot2)

ggplot(type_correct,
       aes(x = n_correct,
           y = 1,
           color = model)) +
  geom_point(size = 4) +
  geom_text(aes(label = n_correct),
            vjust = -1,
            size = 3) +
  scale_color_manual(values = c(
    "XGB" = "orange",
    "GPT" = "steelblue",
    "GPT + Heuristics" = "purple",
    "GPT-mini" = "skyblue",
    "GPT-mini + Heuristics" = "mediumpurple"
  )) +
  scale_x_continuous(limits = c(225, 250)) +
  labs(
    x = "Correct type predictions",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid.major.y = element_blank(),
    legend.position = "bottom"
  )
