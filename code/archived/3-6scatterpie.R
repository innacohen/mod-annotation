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




plot_pie_scatter <- function(points_list, radius = 0.15,
                             title = "Sensitivity by Subtype") {
  
  # Collect all unique colors for the legend
  all_colors <- unique(unlist(lapply(points_list, `[[`, "colors")))
  color_map <- setNames(all_colors, all_colors)
  
  p <- ggplot() +
    coord_fixed(ratio = 5/19) +
    
    # X = sensitivity 0–100%
    scale_x_continuous(
      limits = c(0, 100),
      breaks = seq(0, 100, by = 10),
      labels = function(x) paste0(x, "%")
    ) +
    
    # Y = subtype 1–19
    scale_y_continuous(
      limits = c(0.5, 19.5),
      breaks = 1:19,
      labels = paste("Subtype", 1:19)
    ) +
    
    scale_fill_manual(values = color_map, name = "Model") +
    
    labs(
      title = title,
      x = "Sensitivity (%)",
      y = "Subtype"
    ) +
    
    theme_minimal(base_size = 13) +
    theme(
      legend.position = "right",
      panel.grid.minor = element_blank()
    )
  
  # Add each pie-point
  for (pt in points_list) {
    geoms <- draw_pie_point(pt$x, pt$y, pt$colors, radius = radius)
    for (g in geoms) {
      p <- p + g
    }
  }
  
  p
}



# VERSION 2: ADDING SENSITIVITY -------------------------------------------



library(ggplot2)

# ---- helper: rescale 0–100 → 0–19
scale_pct_to_y <- function(x) x * 19 / 100

# ── Draw pie marker ─────────────────────────────────────────
draw_pie_point <- function(x, y, colors, radius = 0.6) {
  
  n <- length(colors)
  
  if (n == 1) {
    angles <- seq(0, 2*pi, length.out = 100)
    
    df <- data.frame(
      x = x + radius * cos(angles),
      y = y + radius * sin(angles),
      color = colors[1]
    )
    
    return(list(
      geom_polygon(
        data = df,
        aes(x = x, y = y, fill = color),
        color = "white",
        linewidth = 0.3
      )
    ))
  }
  
  geoms <- list()
  slice <- 2*pi/n
  
  for (i in seq_along(colors)) {
    
    a1 <- (i-1)*slice - pi/2
    a2 <- i*slice - pi/2
    ang <- seq(a1, a2, length = 40)
    
    df <- data.frame(
      x = c(x, x + radius*cos(ang), x),
      y = c(y, y + radius*sin(ang), y),
      color = colors[i]
    )
    
    geoms[[i]] <- geom_polygon(
      data = df,
      aes(x = x, y = y, fill = color),
      color = "white",
      linewidth = 0.3
    )
  }
  
  geoms
}

# ── Main plot ───────────────────────────────────────────────
plot_pie_scatter <- function(points_list,
                             radius = .6,
                             title = "Per-Subtype Sensitivity") {
  
  # RESCALE X FIRST
  for (i in seq_along(points_list)) {
    points_list[[i]]$x <- scale_pct_to_y(points_list[[i]]$x)
  }
  
  cols <- unique(unlist(lapply(points_list, `[[`, "colors")))
  cmap <- setNames(cols, cols)
  
  p <- ggplot() +
    coord_equal() +
    
    scale_x_continuous(
      limits = c(0, 19),
      breaks = scale_pct_to_y(seq(0, 100, 10)),
      labels = paste0(seq(0, 100, 10), "%")
    ) +
    
    scale_y_continuous(
      limits = c(.5, 19.5),
      breaks = 1:19,
      labels = paste("Subtype", 1:19)
    ) +
    
    scale_fill_manual(values = cmap, name = "Model") +
    
    labs(
      x = "Sensitivity (%)",
      y = "Subtype",
      title = title
    ) +
    
    theme_minimal(base_size = 13) +
    theme(
      axis.text.y = element_text(size = 9),
      panel.grid.minor = element_blank()
    )
  
  for (pt in points_list) {
    gs <- draw_pie_point(pt$x, pt$y, pt$colors, radius)
    for (g in gs) p <- p + g
  }
  
  p
}

# ── Example ────────────────────────────────────────────────
points_data <- list(
  list(x = 82, y = 1, colors = c("orange","blue")),
  list(x = 65, y = 2, colors = c("purple")),
  list(x = 91, y = 3, colors = c("orange","blue","purple")),
  list(x = 40, y = 4, colors = c("orange")),
  list(x = 75, y = 5, colors = c("blue")),
  list(x = 55, y = 6, colors = c("blue","purple")),
  list(x = 88, y = 7, colors = c("orange","purple"))
)

plot_pie_scatter(points_data)



library(ggplot2)

# ── Helper: rescale 0–100 → 0–19 (internal square coordinates)
scale_pct_to_y <- function(x) x * 19 / 100

# ── Draw pie marker ─────────────────────────────────────────
draw_pie_point <- function(x, y, colors, radius = 0.35) {
  
  n <- length(colors)
  
  if (n == 1) {
    angles <- seq(0, 2*pi, length.out = 100)
    
    df <- data.frame(
      x = x + radius * cos(angles),
      y = y + radius * sin(angles),
      color = colors[1]
    )
    
    return(list(
      geom_polygon(
        data = df,
        aes(x = x, y = y, fill = color),
        color = "white",
        linewidth = 0.3
      )
    ))
  }
  
  geoms <- list()
  slice <- 2*pi/n
  
  for (i in seq_along(colors)) {
    
    a1 <- (i-1)*slice - pi/2
    a2 <- i*slice - pi/2
    ang <- seq(a1, a2, length = 40)
    
    df <- data.frame(
      x = c(x, x + radius*cos(ang), x),
      y = c(y, y + radius*sin(ang), y),
      color = colors[i]
    )
    
    geoms[[i]] <- geom_polygon(
      data = df,
      aes(x = x, y = y, fill = color),
      color = "white",
      linewidth = 0.3
    )
  }
  
  geoms
}

# ── Main plotting function ─────────────────────────────────
plot_pie_scatter <- function(points_list,
                             radius = 0.35,
                             title = "Per-Subtype Sensitivity") {
  
  # rescale X internally
  for (i in seq_along(points_list)) {
    points_list[[i]]$x <- scale_pct_to_y(points_list[[i]]$x)
  }
  
  cols <- unique(unlist(lapply(points_list, `[[`, "colors")))
  cmap <- setNames(cols, cols)
  
  p <- ggplot() +
    coord_equal() +
    
    scale_x_continuous(
      limits = c(0, 19),
      breaks = scale_pct_to_y(seq(0,100,10)),
      labels = paste0(seq(0,100,10),"%")
    ) +
    
    scale_y_continuous(
      limits = c(.5,19.5),
      breaks = 1:19,
      labels = paste("Subtype",1:19)
    ) +
    
    scale_fill_manual(values = cmap, name = "Model") +
    
    labs(x="Sensitivity (%)", y="Subtype", title=title) +
    
    theme_minimal(base_size=13) +
    theme(
      axis.text.y = element_text(size=9),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color="grey85")
    )
  
  for(pt in points_list){
    gs <- draw_pie_point(pt$x, pt$y, pt$colors, radius)
    for(g in gs) p <- p + g
  }
  
  p
}

# ── Example dataframe (replace with your real results) ─────
df <- data.frame(
  subtype = 1:7,
  sens_low  = c(80,65,90,40,75,55,88),
  sens_high = c(85,70,95,45,78,60,92)
)

# ── Build two pies per subtype ─────────────────────────────
points_data <- lapply(1:nrow(df), function(i){
  
  list(
    list(
      x = df$sens_low[i],
      y = df$subtype[i],
      colors = "orange"
    ),
    list(
      x = df$sens_high[i],
      y = df$subtype[i],
      colors = c("blue","purple")
    )
  )
  
}) |> unlist(recursive = FALSE)

# ── Draw plot ──────────────────────────────────────────────
plot_pie_scatter(points_data, radius = 0.35)



# v3 ----------------------------------------------------------------------


library(tidyverse)
library(caret)
library(ggplot2)

# ─────────────────────────────────────────────
# 1. LOAD DATA
# ─────────────────────────────────────────────
pred_df <- read_csv("data/pipeline/predictions.csv")

# ─────────────────────────────────────────────
# 2. FUNCTION: compute sensitivity per model
# ─────────────────────────────────────────────
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
    mutate(true_subtype = sub("^Class:\\s*", "", true_subtype))
}

# ─────────────────────────────────────────────
# 3. COMPUTE SENSITIVITIES
# ─────────────────────────────────────────────
sens_df_gpt <- bind_rows(
  compute_sensitivity(pred_df, xgb_pred_subtype,     "XGB"),
  compute_sensitivity(pred_df, gpt_bl_pred_subtype, "GPT"),
  compute_sensitivity(pred_df, gpt_h_pred_subtype,  "GPT_H")
)

# ─────────────────────────────────────────────
# 4. WIDE FORMAT + SCALE TO %
# ─────────────────────────────────────────────
sens_wide <- sens_df_gpt %>%
  mutate(sensitivity = sensitivity * 100) %>%
  pivot_wider(
    names_from = model,
    values_from = sensitivity
  ) %>%
  arrange(true_subtype)

# ─────────────────────────────────────────────
# 5. COLORS
# ─────────────────────────────────────────────
model_colors <- c(
  XGB   = "orange",
  GPT   = "blue",
  GPT_H = "purple"
)

# ─────────────────────────────────────────────
# 6. CONDITIONAL PIE LOGIC
# ─────────────────────────────────────────────
tol <- 1e-6

points_data <- lapply(1:nrow(sens_wide), function(i) {
  
  row <- sens_wide[i, ]
  
  vals <- row %>%
    select(XGB, GPT, GPT_H) %>%
    unlist()
  
  vals <- vals[!is.na(vals)]
  models_present <- names(vals)
  
  all_equal <- max(vals) - min(vals) < tol
  
  if (all_equal) {
    # ONE PIE
    list(
      list(
        x = vals[1],
        y = i,
        colors = model_colors[models_present]
      )
    )
  } else {
    # MULTIPLE POINTS
    lapply(models_present, function(m) {
      list(
        x = vals[m],
        y = i,
        colors = model_colors[m]
      )
    })
  }
  
}) |> unlist(recursive = FALSE)

# ─────────────────────────────────────────────
# 7. HELPER FUNCTIONS FOR PIE SCATTER
# ─────────────────────────────────────────────

scale_pct_to_y <- function(x) x * 19 / 100

draw_pie_point <- function(x, y, colors, radius = 0.35) {
  
  n <- length(colors)
  
  if (n == 1) {
    angles <- seq(0, 2*pi, length.out = 100)
    
    df <- data.frame(
      x = x + radius * cos(angles),
      y = y + radius * sin(angles),
      color = colors[1]
    )
    
    return(list(
      geom_polygon(
        data = df,
        aes(x = x, y = y, fill = color),
        color = "white",
        linewidth = 0.3
      )
    ))
  }
  
  geoms <- list()
  slice <- 2*pi/n
  
  for (i in seq_along(colors)) {
    
    a1 <- (i-1)*slice - pi/2
    a2 <- i*slice - pi/2
    ang <- seq(a1, a2, length = 40)
    
    df <- data.frame(
      x = c(x, x + radius*cos(ang), x),
      y = c(y, y + radius*sin(ang), y),
      color = colors[i]
    )
    
    geoms[[i]] <- geom_polygon(
      data = df,
      aes(x = x, y = y, fill = color),
      color = "white",
      linewidth = 0.3
    )
  }
  
  geoms
}

plot_pie_scatter <- function(points_list,
                             radius = 0.35,
                             title = "Per-Subtype Sensitivity") {
  
  for (i in seq_along(points_list)) {
    points_list[[i]]$x <- scale_pct_to_y(points_list[[i]]$x)
  }
  
  cols <- unique(unlist(lapply(points_list, `[[`, "colors")))
  cmap <- setNames(cols, cols)
  
  p <- ggplot() +
    coord_equal() +
    
    scale_x_continuous(
      limits = c(0, 19),
      breaks = scale_pct_to_y(seq(0,100,10)),
      labels = paste0(seq(0,100,10),"%")
    ) +
    
    scale_y_continuous(
      limits = c(.5,19.5),
      breaks = 1:nrow(sens_wide),
      labels = sens_wide$true_subtype
    ) +
    
    scale_fill_manual(values = cmap, name = "Model") +
    
    labs(x="Sensitivity (%)", y="Subtype", title=title) +
    
    theme_minimal(base_size=13) +
    theme(
      axis.text.y = element_text(size=9),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color="grey85")
    )
  
  for(pt in points_list){
    gs <- draw_pie_point(pt$x, pt$y, pt$colors, radius)
    for(g in gs) p <- p + g
  }
  
  p
}

# ─────────────────────────────────────────────
# 8. PLOT
# ─────────────────────────────────────────────
plot_pie_scatter(points_data, radius = 0.35)

