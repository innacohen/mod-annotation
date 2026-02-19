source("code/_utils.R")



# Function to draw a single pie-chart point
draw_pie_point <- function(x, y, colors, radius = 0.15) {
  n <- length(colors)
  
  if (n == 1) {
    # Simple filled circle
    angles <- seq(0, 2 * pi, length.out = 100)
    df <- data.frame(
      x = x + radius * cos(angles),
      y = y + radius * sin(angles),
      color = colors[1]
    )
    return(list(
      geom_polygon(data = df, aes(x = x, y = y, fill = color, group = 1),
                   color = "white", linewidth = 0.3)
    ))
  }
  
  # Multi-color: draw pie slices
  slice_angle <- 2 * pi / n
  geoms <- list()
  
  for (i in seq_along(colors)) {
    start_angle <- (i - 1) * slice_angle - pi / 2
    end_angle   <- i       * slice_angle - pi / 2
    
    angles <- seq(start_angle, end_angle, length.out = 30)
    
    slice_df <- data.frame(
      x     = c(x, x + radius * cos(angles), x),
      y     = c(y, y + radius * sin(angles), y),
      color = colors[i]
    )
    
    geoms[[i]] <- geom_polygon(
      data      = slice_df,
      aes(x = x, y = y, fill = color, group = 1),
      color     = "white",
      linewidth = 0.3
    )
  }
  
  geoms
}

# ── Main plotting function ────────────────────────────────────────────────────
# points_list : list of named lists with fields x, y, colors
#   e.g. list(list(x=4, y=2, colors=c("orange","blue")),
#             list(x=1, y=1, colors=c("purple")),
#             list(x=0, y=0, colors=c("orange","blue","purple")))
# radius      : size of each pie marker (in data units)

plot_pie_scatter <- function(points_list, radius = 0.15,
                             title = "Pie-Scatter Plot") {
  
  # Collect all unique colors for the legend
  all_colors <- unique(unlist(lapply(points_list, `[[`, "colors")))
  
  # Color map – keep named colors as-is; everything maps to itself
  color_map <- setNames(all_colors, all_colors)
  
  # Build base plot
  p <- ggplot() +
    coord_fixed() +
    scale_fill_manual(values = color_map, name = "Color") +
    labs(title = title, x = "X", y = "Y") +
    theme_minimal(base_size = 13) +
    theme(legend.position = "right")
  
  # Add each pie-point
  for (pt in points_list) {
    geoms <- draw_pie_point(pt$x, pt$y, pt$colors, radius = radius)
    for (g in geoms) {
      p <- p + g
    }
  }
  
  p
}

# ── Example usage ─────────────────────────────────────────────────────────────
points_data <- list(
  list(x = 4,   y = 2,   colors = c("orange", "blue")),
  list(x = 1,   y = 1,   colors = c("purple")),
  list(x = 0,   y = 0,   colors = c("orange", "blue", "purple")),
  list(x = 3,   y = 3,   colors = c("orange")),
  list(x = 2,   y = 4,   colors = c("blue")),
  list(x = 5,   y = 1,   colors = c("blue", "purple")),
  list(x = 1.5, y = 3.5, colors = c("orange", "purple")),
  list(x = 4.5, y = 4,   colors = c("orange", "blue", "purple"))
)

plot_pie_scatter(points_data, radius = 0.2, title = "Pie-Scatter Plot Example")



#pred_df <- read_csv("data/pipeline/predictions.csv")


# ── 1. Compute per-subtype sensitivity ────────────────────────────────────────
#pred_df2 <- read_csv("data/pipeline/predictions.csv") %>%
#  select(file_hash, true_subtype, xgb_pred_subtype, gpt_bl_pred_subtype, gpt_h_pred_subtype)

