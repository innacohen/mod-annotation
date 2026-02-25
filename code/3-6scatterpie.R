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



# ACTUAL DATA -------------------------------------------------------------

library(tidyverse)
library(ggplot2)

# ─────────────────────────────────────────────
# Draw pie marker
# ─────────────────────────────────────────────

draw_pie_point <- function(x, y, colors, radius = 0.35) {
  
  n <- length(colors)
  
  if (n == 1) {
    ang <- seq(0, 2*pi, length.out = 60)
    
    df <- data.frame(
      x = x + radius*cos(ang),
      y = y + radius*sin(ang),
      color = colors[1]
    )
    
    return(list(
      geom_polygon(data=df,
                   aes(x=x,y=y,fill=color),
                   color="white",linewidth=.3)
    ))
  }
  
  slice <- 2*pi/n
  geoms <- list()
  
  for(i in seq_along(colors)){
    
    a1 <- (i-1)*slice - pi/2
    a2 <- i*slice - pi/2
    ang <- seq(a1,a2,length=40)
    
    df <- data.frame(
      x=c(x,x+radius*cos(ang),x),
      y=c(y,y+radius*sin(ang),y),
      color=colors[i]
    )
    
    geoms[[i]] <- geom_polygon(
      data=df,
      aes(x=x,y=y,fill=color),
      color="white",
      linewidth=.3
    )
  }
  
  geoms
}


# ─────────────────────────────────────────────
# Plot function
# ─────────────────────────────────────────────

plot_pie_scatter <- function(points_list,
                             radius=.35,
                             title="Per-Subtype Sensitivity") {
  
  cols <- unique(unlist(lapply(points_list, `[[`, "colors")))
  cmap <- setNames(cols, cols)
  
  p <- ggplot() +
    coord_equal() +
    
    scale_x_continuous(
      limits=c(0,100),
      breaks=seq(0,100,10),
      labels=paste0(seq(0,100,10),"%")
    ) +
    
    scale_y_continuous(
      limits=c(.5,19.5),
      breaks=1:19,
      labels=paste("Subtype",1:19)
    ) +
    
    scale_fill_manual(values=cmap,name="Model") +
    
    labs(x="Sensitivity (%)",y="Subtype",title=title) +
    
    theme_minimal(base_size=13) +
    theme(panel.grid.minor=element_blank())
  
  for(pt in points_list){
    gs <- draw_pie_point(pt$x,pt$y,pt$colors,radius)
    for(g in gs) p <- p + g
  }
  
  p
}


pred_df <- read_csv("data/pipeline/predictions.csv")

pred_df2 <- pred_df %>%
  select(
    file_hash,
    true_subtype,
    xgb_pred_subtype,
    gpt_bl_pred_subtype,
    gpt_h_pred_subtype
  )

# ensure numeric subtype
pred_df2 <- pred_df2 %>%
  mutate(true_subtype = as.integer(true_subtype))


# ─────────────────────────────────────────────
# Sensitivity function
# ─────────────────────────────────────────────

compute_sensitivity <- function(df, pred_col, model_name) {
  
  df %>%
    filter(!is.na(true_subtype)) %>%
    group_by(true_subtype) %>%
    summarise(
      TP = sum({{ pred_col }} == true_subtype, na.rm = TRUE),
      FN = sum({{ pred_col }} != true_subtype, na.rm = TRUE),
      sensitivity = TP / (TP + FN),
      .groups = "drop"
    ) %>%
    mutate(model = model_name)
}


# ─────────────────────────────────────────────
# Compute sensitivities
# ─────────────────────────────────────────────

sens_xgb <- compute_sensitivity(pred_df2, xgb_pred_subtype, "XGB")
sens_gpt_bl <- compute_sensitivity(pred_df2, gpt_bl_pred_subtype, "GPT_base")
sens_gpt_h <- compute_sensitivity(pred_df2, gpt_h_pred_subtype, "GPT_h")

sens_df <- bind_rows(sens_xgb, sens_gpt_bl, sens_gpt_h)


# ─────────────────────────────────────────────
# Wide format
# ─────────────────────────────────────────────

sens_wide <- sens_df %>%
  select(true_subtype, model, sensitivity) %>%
  pivot_wider(names_from = model, values_from = sensitivity) %>%
  arrange(true_subtype) %>%
  mutate(
    true_subtype = as.integer(true_subtype),
    y_pos = row_number()
  )



model_colors <- c(
  XGB="orange",
  GPT_base="blue",
  GPT_h="purple"
)


# ─────────────────────────────────────────────
# Build points
# ─────────────────────────────────────────────

points_data <- lapply(seq_len(nrow(sens_wide)),function(i){
  
  row <- sens_wide[i,]
  
  vals <- c(XGB=row$XGB,GPT_base=row$GPT_base,GPT_h=row$GPT_h)
  
  m <- max(vals,na.rm=TRUE)
  winners <- names(vals)[vals==m]
  
  list(
    x=m*100,
    y=row$y,
    colors=model_colors[winners]
  )
})


# ─────────────────────────────────────────────
# Plot
# ─────────────────────────────────────────────

plot_pie_scatter(points_data, radius=.35,
                 title="Per-Subtype Sensitivity (Real Data)")
