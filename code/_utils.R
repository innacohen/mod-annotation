

# LIBRARIES ---------------------------------------------------------------

library(tidyverse)
library(naniar)
library(table1)
setwd("~/palmer_scratch/mod-extract/code")



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
    labels = c("full", "minimal"),        # legend/strip labels
    style = c("dumbbell", "winner"),      # point styling
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
    # --- NEW: annotation controls ---
    annotate_values = FALSE,              # add % labels near points
    percent_accuracy = 1,                 # 0, 1, or 0.1, etc.
    label_size = 3,
    # label horizontal justifications (negative -> to the right; >1 -> to the left of point)
    hjust_winner = -0.3,
    hjust_loser  =  1.3,
    hjust_tie    = -0.3,
    # X-axis domain controls
    x_min = 0, x_max = 1.0,               # sensitivities in [0,1]
    extend_right_if_annotated = 0.10      # adds to x_max when annotate_values = TRUE
) {
  labels   <- match.arg(labels)
  order_by <- match.arg(order_by)
  style    <- match.arg(style)
  
  # per-subtype sensitivity, family, delta, winner
  sens <- df %>%
    dplyr::group_by(.data[[truth_col]]) %>%
    dplyr::summarise(
      sens_xgb = mean(.data[[xgb_match_col]], na.rm = TRUE),
      sens_gpt = mean(.data[[gpt_match_col]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      family = purrr::map_chr(.data[[truth_col]], family_fun),
      diff   = sens_gpt - sens_xgb,
      winner = dplyr::case_when(
        diff > 0 ~ "GPT",
        diff < 0 ~ "XGB",
        TRUE     ~ "Tie"
      )
    ) %>%
    dplyr::mutate(family = factor(.data$family, levels = family_order))
  
  # ordering
  sens <- {
    if (order_by == "abs_delta") {
      sens %>%
        dplyr::group_by(.data$family) %>%
        dplyr::arrange(dplyr::desc(abs(.data$diff)), .by_group = TRUE) %>%
        dplyr::ungroup()
    } else if (order_by == "sens_xgb") {
      sens %>% dplyr::arrange(.data$family, dplyr::desc(.data$sens_xgb))
    } else if (order_by == "sens_gpt") {
      sens %>% dplyr::arrange(.data$family, dplyr::desc(.data$sens_gpt))
    } else { # "delta"
      sens %>% dplyr::arrange(.data$family, dplyr::desc(.data$diff))
    }
  } %>%
    dplyr::mutate(
      !!truth_col := factor(.data[[truth_col]], levels = rev(unique(.data[[truth_col]])))
    )
  
  # long format for plotting (+ carry winner per subtype)
  sens_long <- sens %>%
    tidyr::pivot_longer(
      cols = c("sens_xgb", "sens_gpt"),
      names_to = "model",
      values_to = "sensitivity"
    ) %>%
    dplyr::mutate(model = dplyr::recode(.data$model, sens_xgb = "XGB", sens_gpt = "GPT"))
  
  # default subtitle for gap+facets
  if (is.null(subtitle) && facet_by_family && order_by == "abs_delta") {
    subtitle <- if (style == "winner") {
      "Winner in color; loser hollow; ties in grey — ordered by biggest gap within each family"
    } else {
      "Ordered by biggest gap within each family"
    }
  }
  
  # axis limits (optionally extend right to make room for labels)
  x_right <- if (annotate_values) x_max + extend_right_if_annotated else x_max
  
  # base plot
  p <- ggplot2::ggplot(
    sens_long,
    ggplot2::aes(x = .data$sensitivity, y = .data[[truth_col]], group = .data[[truth_col]])
  ) +
    ggplot2::geom_line(color = line_color, linewidth = 0.8) +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = percent_accuracy),
                                limits = c(x_min, x_right)) +
    ggplot2::labs(title = title, subtitle = subtitle, x = x_lab, y = y_lab) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor.x = ggplot2::element_blank()
    )
  
  if (style == "dumbbell") {
    # Classic dumbbell: both points colored by model
    p <- p +
      ggplot2::geom_point(
        ggplot2::aes(fill = .data$model),
        shape = 21, size = 4, color = point_outline, stroke = 1
      ) +
      ggplot2::scale_fill_manual(values = c("XGB" = xgb_color, "GPT" = gpt_color), name = "Model")
  } else {
    # Winner/loser style
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
  
  # add percent labels if requested
  if (annotate_values) {
    # winner labels to the right
    p <- p +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model == .data$winner & .data$winner != "Tie"),
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_winner, size = label_size, color = "black"
      ) +
      # loser labels to the left
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model != .data$winner & .data$winner != "Tie"),
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_loser, size = label_size, color = "black"
      ) +
      # tie labels to the right
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$winner == "Tie"),
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_tie, size = label_size, color = "black"
      )
  }
  
  if (facet_by_family) {
    p <- p +
      ggplot2::facet_grid(family ~ ., scales = "free_y", space = "free_y") +
      ggplot2::theme(strip.text.y = ggplot2::element_text(angle = 0, face = "bold"))
  }
  
  # label mode
  if (labels == "minimal") {
    p <- p +
      ggplot2::theme(strip.text.y = ggplot2::element_blank(),
                     legend.position = "none")
  }
  
  p
}
