

# LIBRARIES ---------------------------------------------------------------

library(tidyverse)
library(naniar)
library(table1)
setwd("~/palmer_scratch/mod-extract")
dd = read_csv("data/pipeline/feature_dd.csv")
xgb_feat_df = read_csv("data/pipeline/feature_importance_global.csv")
pred_df = read_csv("data/pipeline/predictions_with_shap.csv")
ant_raw_df = read_csv("data/pipeline/ant_with_excluded_samples.csv")
ant_pre_df = read_csv("data/pipeline/preprocessed.csv")
  
# FUNCTIONS ---------------------------------------------------------------


### Render p-value
# Concise output for followup table (only Yes's, instead of Yes/No)
#Show the mean (SD) and median (IQR) for continuous variables
pvalue <- function(x, ...) {
  # Construct vectors of data y, and groups (strata) g
  y <- unlist(x)
  g <- factor(rep(1:length(x), times = sapply(x, length)))
  
  if (is.numeric(y)) {
    # For numeric variables with more than two groups, perform a one-way ANOVA
    if (length(unique(g)) > 2) {
      p <- summary(aov(y ~ g))[[1]]["Pr(>F)"][1]
    } else {
      # For exactly two groups, use a t-test
      p <- t.test(y ~ g)$p.value
    }
  } else {
    # For categorical variables, perform a chi-squared test of independence
    p <- chisq.test(table(y, g))$p.value
  }
  
  # Format the p-value without HTML substitution
  c("", format.pval(p, digits = 3, eps = 0.001))
}



# Family inference
infer_family <- function(s) {
  s <- trimws(s)
  if (grepl("^I\\s*Other", s, ignore.case = TRUE)) {
    "Other"
  } else if (grepl("(^R\\b|Receptor)", s, ignore.case = TRUE)) {
    "Receptors"
  } else if (grepl("I\\s*H\\b|Ih\\b|HCN|H-?current", s, ignore.case = TRUE)) {
    "H-Current"
  } else if (grepl("\\bK\\b|Potassium", s, ignore.case = TRUE)) {
    "K"
  } else if (grepl("\\bNa\\b|Sodium", s, ignore.case = TRUE)) {
    "Na"
  } else if (grepl("\\bCa\\b|Calcium", s, ignore.case = TRUE)) {
    "Calcium"
  } else if (grepl("\\bNeither\\b", s, ignore.case = TRUE)) {
    "Neither"
  } else {
    "Other"
  }
}
  
  

# ARROW PLOT --------------------------------------------------------------

  
plot_arrow <- function(
    df,
    truth_col = "true_subtype",
    xgb_match_col = "xgb_subtype_match",
    gpt_match_col = "gpt_subtype_match",
    family_fun = infer_family,          # function: chr -> family
    family_order = c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither"),
    title = "Subtype Sensitivity Change: XGB \u2192 GPT",  # arrow
    x_lab = "Sensitivity (TP %)",
    y_lab = NULL,
    neg_color = "firebrick",
    pos_color = "steelblue",
    base_size = 14
  ) {
    stopifnot(is.function(family_fun))
    req_cols <- c(truth_col, xgb_match_col, gpt_match_col)
    stopifnot(all(req_cols %in% names(df)))
    
    # Compute per-subtype sensitivity
    sens <- df %>%
      dplyr::group_by(.data[[truth_col]]) %>%
      dplyr::summarise(
        sens_xgb = mean(.data[[xgb_match_col]], na.rm = TRUE),
        sens_gpt = mean(.data[[gpt_match_col]], na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        family = purrr::map_chr(.data[[truth_col]], family_fun)
      )
    
    # Order and compute deltas
    sens <- sens %>%
      dplyr::mutate(family = factor(.data$family, levels = family_order)) %>%
      dplyr::arrange(.data$family, dplyr::desc(.data$sens_xgb)) %>%
      dplyr::mutate(
        !!truth_col := factor(.data[[truth_col]], levels = rev(unique(.data[[truth_col]]))),
        change_sens = sens_gpt - sens_xgb
      )
    
    # Long format for path/arrows
    sens_long <- sens %>%
      tidyr::pivot_longer(
        cols = c("sens_xgb", "sens_gpt"),
        names_to = "model",
        values_to = "sensitivity"
      ) %>%
      dplyr::mutate(
        model = dplyr::recode(.data$model, sens_xgb = "XGB", sens_gpt = "GPT")
      )
    
    # Plot
    ggplot2::ggplot(
      sens_long,
      ggplot2::aes(x = .data$sensitivity, y = .data[[truth_col]], group = .data[[truth_col]])
    ) +
      ggplot2::geom_path(
        ggplot2::aes(color = .data$change_sens < 0),
        arrow = grid::arrow(length = grid::unit(0.3, "cm"), type = "closed"),
        linewidth = 1
      ) +
      ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
      ggplot2::scale_color_manual(values = c(`TRUE` = neg_color, `FALSE` = pos_color)) +
      ggplot2::labs(title = title, x = x_lab, y = y_lab) +
      ggplot2::theme_minimal(base_size = base_size) +
      ggplot2::theme(
        panel.grid.major.y = ggplot2::element_blank(),
        panel.grid.minor.x = ggplot2::element_blank(),
        legend.position = "none"
      )
  }
  
  
  
# DUMBELL PLOT ------------------------------------------------------------

plot_db <- function(
    df,
    truth_col = "true_subtype",
    xgb_match_col = "xgb_subtype_match",
    gpt_match_col = "gpt_subtype_match",
    family_fun = infer_family,   # function(char) -> family
    family_order = c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither"),
    order_by = c("sens_xgb", "sens_gpt", "delta", "abs_delta"),  # abs_delta = biggest gap within family
    facet_by_family = FALSE,
    labels = c("full", "minimal"),      # legend & facet strip labels
    style = c("dumbbell", "winner"),    # point styling
    annotate = c("none", "percent", "counts"),  # <-- mutually exclusive
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = NULL,
    x_lab = "Sensitivity (TP %)",
    y_lab = NULL,
    xgb_color = "steelblue",
    gpt_color = "firebrick",
    tie_color = "grey50",
    line_color = "#999999",
    point_outline = "#333333",
    base_size = 14,
    # Percent annotation controls (used when annotate == "percent")
    percent_accuracy = 1,
    label_size = 3,
    hjust_winner = -0.3,
    hjust_loser  =  1.3,
    hjust_tie    = -0.3,
    # Counts annotation controls (used when annotate == "counts")
    counts_label_size = 3,
    counts_hjust_winner = -0.3,
    counts_hjust_loser  =  1.3,
    counts_hjust_tie    = -0.3,
    counts_nudge_x_winner = 0.01,
    counts_nudge_x_loser  = 0.00,
    counts_nudge_x_tie    = 0.01,
    # Axis domain
    x_min = 0, x_max = 1.0,
    extend_right_if_annotated = 0.10
) {
  labels   <- match.arg(labels)
  order_by <- match.arg(order_by)
  style    <- match.arg(style)
  annotate <- match.arg(annotate)
  
  # --- Build long-format counts & sensitivities (per model) ---
  counts_long <- dplyr::bind_rows(
    df %>%
      dplyr::group_by(.data[[truth_col]]) %>%
      dplyr::summarise(
        correct = sum(.data[[xgb_match_col]], na.rm = TRUE),
        total   = sum(!is.na(.data[[xgb_match_col]])),
        .groups = "drop"
      ) %>% dplyr::mutate(model = "XGB"),
    df %>%
      dplyr::group_by(.data[[truth_col]]) %>%
      dplyr::summarise(
        correct = sum(.data[[gpt_match_col]], na.rm = TRUE),
        total   = sum(!is.na(.data[[gpt_match_col]])),
        .groups = "drop"
      ) %>% dplyr::mutate(model = "GPT")
  ) %>%
    dplyr::mutate(
      sensitivity  = dplyr::if_else(total > 0, correct / total, NA_real_),
      label_counts = paste0(correct, "/", total),
      family = purrr::map_chr(.data[[truth_col]], family_fun)
    )
  
  # Winner/loser per subtype (compare sensitivities)
  winner_df <- counts_long %>%
    dplyr::select(.data[[truth_col]], .data$model, .data$sensitivity) %>%
    tidyr::pivot_wider(names_from = .data$model, values_from = .data$sensitivity) %>%
    dplyr::mutate(
      diff   = GPT - XGB,
      winner = dplyr::case_when(
        diff > 0 ~ "GPT",
        diff < 0 ~ "XGB",
        TRUE     ~ "Tie"
      )
    ) %>%
    dplyr::select(.data[[truth_col]], .data$winner, .data$diff)
  
  sens_long <- counts_long %>%
    dplyr::left_join(winner_df, by = truth_col) %>%
    dplyr::mutate(family = factor(.data$family, levels = family_order))
  
  # --- Ordering by choice (robust) ---
  if (order_by == "abs_delta") {
    sens_long <- sens_long %>%
      dplyr::group_by(family) %>%
      dplyr::arrange(dplyr::desc(abs(.data$diff)), .by_group = TRUE) %>%
      dplyr::ungroup()
    
    levs <- sens_long %>%
      dplyr::pull(!!rlang::sym(truth_col)) %>%
      unique()
    
  } else if (order_by == "sens_xgb") {
    ord <- sens_long %>%
      dplyr::filter(.data$model == "XGB") %>%
      dplyr::arrange(.data$family, dplyr::desc(.data$sensitivity))
    levs <- ord %>% dplyr::pull(!!rlang::sym(truth_col)) %>% unique()
    
  } else if (order_by == "sens_gpt") {
    ord <- sens_long %>%
      dplyr::filter(.data$model == "GPT") %>%
      dplyr::arrange(.data$family, dplyr::desc(.data$sensitivity))
    levs <- ord %>% dplyr::pull(!!rlang::sym(truth_col)) %>% unique()
    
  } else { # "delta"
    ord <- counts_long %>%
      dplyr::distinct(!!rlang::sym(truth_col), family) %>%
      dplyr::left_join(winner_df, by = truth_col) %>%
      dplyr::arrange(family, dplyr::desc(.data$diff))
    levs <- ord %>% dplyr::pull(!!rlang::sym(truth_col))
  }
  
  sens_long <- sens_long %>%
    dplyr::mutate(!!truth_col := factor(.data[[truth_col]], levels = rev(levs)))
  
  # Default subtitle for gap+facets
  if (is.null(subtitle) && facet_by_family && order_by == "abs_delta") {
    subtitle <- if (style == "winner") {
      "Winner in color; loser hollow; ties in grey — ordered by biggest gap within each family"
    } else {
      "Ordered by biggest gap within each family"
    }
  }
  
  # Axis limits (optionally extend right to make room for labels)
  needs_extend <- annotate != "none"
  x_right <- if (needs_extend) x_max + extend_right_if_annotated else x_max
  
  # --- Base plot ---
  p <- ggplot2::ggplot(
    sens_long,
    ggplot2::aes(x = .data$sensitivity, y = .data[[truth_col]], group = .data[[truth_col]])
  ) +
    ggplot2::geom_line(color = line_color, linewidth = 0.8) +
    ggplot2::scale_x_continuous(
      labels = scales::percent_format(accuracy = percent_accuracy),
      limits = c(x_min, x_right)
    ) +
    ggplot2::labs(title = title, subtitle = subtitle, x = x_lab, y = y_lab) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor.x = ggplot2::element_blank()
    )
  
  # --- Points (by style) ---
  if (style == "dumbbell") {
    p <- p +
      ggplot2::geom_point(
        ggplot2::aes(fill = .data$model),
        shape = 21, size = 4, color = point_outline, stroke = 1
      ) +
      ggplot2::scale_fill_manual(values = c("XGB" = xgb_color, "GPT" = gpt_color), name = "Model")
  } else {
    winner_colors <- c("GPT" = gpt_color, "XGB" = xgb_color)
    p <- p +
      ggplot2::geom_point(
        data = dplyr::filter(sens_long, .data$model == .data$winner & .data$winner != "Tie"),
        ggplot2::aes(fill = .data$model),
        shape = 21, size = 4, color = "black", stroke = 1
      ) +
      ggplot2::scale_fill_manual(values = winner_colors, guide = "none") +
      ggplot2::geom_point(
        data = dplyr::filter(sens_long, .data$model != .data$winner & .data$winner != "Tie"),
        shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8
      ) +
      ggplot2::geom_point(
        data = dplyr::filter(sens_long, .data$winner == "Tie"),
        shape = 21, size = 4, fill = tie_color, color = "black", stroke = 1
      )
  }
  
  # --- Annotations (mutually exclusive) ---
  if (annotate == "percent") {
    p <- p +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model == .data$winner & .data$winner != "Tie"),
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_winner, size = label_size, color = "black"
      ) +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model != .data$winner & .data$winner != "Tie"),
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_loser, size = label_size, color = "black"
      ) +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$winner == "Tie"),
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_tie, size = label_size, color = "black"
      )
  } else if (annotate == "counts") {
    p <- p +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model == .data$winner & .data$winner != "Tie"),
        ggplot2::aes(label = .data$label_counts),
        hjust = counts_hjust_winner, size = counts_label_size, color = "black",
        nudge_x = counts_nudge_x_winner
      ) +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model != .data$winner & .data$winner != "Tie"),
        ggplot2::aes(label = .data$label_counts),
        hjust = counts_hjust_loser, size = counts_label_size, color = "black",
        nudge_x = counts_nudge_x_loser
      ) +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$winner == "Tie"),
        ggplot2::aes(label = .data$label_counts),
        hjust = counts_hjust_tie, size = counts_label_size, color = "black",
        nudge_x = counts_nudge_x_tie
      )
  }
  
  # Facets & label mode
  if (facet_by_family) {
    p <- p +
      ggplot2::facet_grid(family ~ ., scales = "free_y", space = "free_y") +
      ggplot2::theme(strip.text.y = ggplot2::element_text(angle = 0, face = "bold"))
  }
  if (labels == "minimal") {
    p <- p +
      ggplot2::theme(strip.text.y = ggplot2::element_blank(),
                     legend.position = "none")
  }
  
  p
}



# TOP FEATURES BARPLOT ----------------------------------------------------

library(tidyverse)

# If you need to read it:
# xgb_feat_df <- read_csv("feature_importance.csv", show_col_types = FALSE)
plot_top_features <- function(
    xgb_feat_df,
    top_n = 15,
    legend = c("full", "minimal", "none"),  # "minimal"/"none" hide legend
    base_size = 20,                          # increase for bigger text
    sim_color = "steelblue",
    text_color = "#6E7B8B"
) {
  legend <- match.arg(legend)
  
  df_plot <- xgb_feat_df %>%
    dplyr::mutate(
      feature_type = dplyr::if_else(stringr::str_detect(feature, "_simfeat"),
                                    "Simulation-derived", "Text-derived")
    ) %>%
    dplyr::arrange(dplyr::desc(gain)) %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::mutate(feature = forcats::fct_reorder(feature, gain))
  
  p <- ggplot2::ggplot(df_plot, ggplot2::aes(x = gain, y = feature, fill = feature_type)) +
    ggplot2::geom_col() +
    ggplot2::labs(
      title = paste0("Top ", nrow(df_plot), " Features"),
      x = "Gain importance",
      y = "Feature",
      fill = if (legend == "full") "Feature type" else NULL
    ) +
    ggplot2::scale_fill_manual(values = c("Simulation-derived" = sim_color,
                                          "Text-derived" = text_color)) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      axis.text.y = element_text(color = "black"),
      axis.title.y = element_text(color = "black"),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank()
    )
  
  if (legend %in% c("minimal", "none")) {
    p <- p + ggplot2::theme(legend.position = "none")
  }
  
  p
}

# Usage
plot_top_features(xgb_feat_df, top_n = 15, base_size=20, legend="minimal")
# print(p)
# ggsave("top_features.png", p, width = 8, height = 5, dpi = 300)

