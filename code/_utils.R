

# LIBRARIES ---------------------------------------------------------------

library(tidyverse)
library(naniar)
library(table1)
library(janitor)
library(readxl)
library(flextable)
library(officer)

# FUNCTIONS ---------------------------------------------------------------

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
  


write_word_table <- function(var, doc){
  # Adjust the flextable layout (for example, resizing columns and setting font size)
  var <- var %>%
    flextable::set_table_properties(width = 1, layout = "autofit") %>%
    flextable::fontsize(size = 8)  # Adjust font size as needed
  
  # Add the flextable to the document
  doc %>%
    body_add_flextable(var) %>%
    body_add_break()  # Add a page break after the table
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
    order_by = c("delta", "sens_xgb", "sens_gpt", "abs_delta"),  # delta = biggest difference (GPT-XGB) first
    facet_by_family = TRUE,      # Changed default to TRUE for grouping by family
    labels = c("full", "minimal"),      # legend & facet strip labels
    style = c("dumbbell", "winner"),    # point styling
    annotate = c("percent", "none", "counts"),  # Changed default to "percent" for inline labels
    show_grid = TRUE,                           # Option to show/hide grid lines
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = NULL,
    x_lab = "Sensitivity (TP %)",
    y_lab = NULL,
    xgb_color = "#FFA273",       # Changed from "steelblue" to orange
    gpt_color = "#0070C0",       # Changed from "firebrick" to blue
    tie_color = "grey50",
    line_color = "#999999",
    point_outline = "#333333",
    base_size = 16,              # Increased from 14 for larger base font
    # Percent annotation controls (used when annotate == "percent")
    percent_accuracy = 1,
    label_size = 4,          # Increased from 3 to 4 for larger % labels
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
  
  # --- Ordering by choice (robust) - Modified to prioritize "delta" ---
  if (order_by == "delta") {
    # Sort by difference (GPT - XGB) with biggest positive differences first
    ord <- counts_long %>%
      dplyr::distinct(!!rlang::sym(truth_col), family) %>%
      dplyr::left_join(winner_df, by = truth_col) %>%
      dplyr::arrange(family, dplyr::desc(.data$diff))
    levs <- ord %>% dplyr::pull(!!rlang::sym(truth_col))
    
  } else if (order_by == "abs_delta") {
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
    
  } else { # "sens_gpt"
    ord <- sens_long %>%
      dplyr::filter(.data$model == "GPT") %>%
      dplyr::arrange(.data$family, dplyr::desc(.data$sensitivity))
    levs <- ord %>% dplyr::pull(!!rlang::sym(truth_col)) %>% unique()
  }
  
  sens_long <- sens_long %>%
    dplyr::mutate(!!truth_col := factor(.data[[truth_col]], levels = rev(levs)))
  
  # Default subtitle for gap+facets
  if (is.null(subtitle) && facet_by_family && order_by == "delta") {
    subtitle <- if (style == "winner") {
      ""
    } else {
      ""
    }
  }
  
  # Axis limits (optionally extend right to make room for labels)
  needs_extend <- annotate != "none"
  x_right <- if (needs_extend) x_max + extend_right_if_annotated else x_max
  
  # --- Base plot with optional grid ---
  p <- ggplot2::ggplot(
    sens_long,
    ggplot2::aes(x = .data$sensitivity, y = .data[[truth_col]], group = .data[[truth_col]])
  ) +
    ggplot2::geom_line(color = line_color, linewidth = 0.5) +  # Thinner connectors (was 0.8)
    ggplot2::scale_x_continuous(
      labels = scales::percent_format(accuracy = percent_accuracy),
      limits = c(x_min, x_right),
      breaks = if (show_grid) c(0, 0.25, 0.5, 0.75, 1.0) else NULL  # Conditional grid breaks
    ) +
    ggplot2::labs(title = title, subtitle = subtitle, x = x_lab, y = y_lab) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor.x = ggplot2::element_blank(),
      panel.grid.minor.y = ggplot2::element_blank(),  # Remove minor y grid too
      panel.grid.major.x = if (!show_grid) ggplot2::element_blank() else ggplot2::element_line(),  # Conditional major x grid
      axis.text.y = ggplot2::element_text(color = "black")  # Make y-axis labels black
    )
  
  # --- Points (by style) - Thicker points ---
  if (style == "dumbbell") {
    p <- p +
      ggplot2::geom_point(
        ggplot2::aes(fill = .data$model),
        shape = 21, size = 5, color = point_outline, stroke = 1  # Increased size from 4 to 5
      ) +
      ggplot2::scale_fill_manual(values = c("XGB" = xgb_color, "GPT" = gpt_color), name = "Model")
  } else {
    winner_colors <- c("GPT" = gpt_color, "XGB" = xgb_color)
    p <- p +
      ggplot2::geom_point(
        data = dplyr::filter(sens_long, .data$model == .data$winner & .data$winner != "Tie"),
        ggplot2::aes(fill = .data$model),
        shape = 21, size = 5, color = "black", stroke = 1  # Increased size from 4 to 5
      ) +
      ggplot2::scale_fill_manual(values = winner_colors, guide = "none") +
      ggplot2::geom_point(
        data = dplyr::filter(sens_long, .data$model != .data$winner & .data$winner != "Tie"),
        shape = 21, size = 3.5, fill = "white", color = "black", stroke = 0.8  # Increased size from 2.5 to 3.5
      ) +
      ggplot2::geom_point(
        data = dplyr::filter(sens_long, .data$winner == "Tie"),
        shape = 21, size = 5, fill = tie_color, color = "black", stroke = 1  # Increased size from 4 to 5
      )
  }
  
  # --- Annotations - Modified to show only winner labels ---
  if (annotate == "percent") {
    p <- p +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model == .data$winner),  # Only winners get labels
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_winner, size = label_size, color = "black", fontface = "bold"  # Added bold
      )
  } else if (annotate == "counts") {
    p <- p +
      ggplot2::geom_text(
        data = dplyr::filter(sens_long, .data$model == .data$winner),  # Only winners get labels
        ggplot2::aes(label = .data$label_counts),
        hjust = counts_hjust_winner, size = counts_label_size, color = "black",
        nudge_x = counts_nudge_x_winner, fontface = "bold"  # Added bold
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

# MARGIN ------------------------------------------------------------------

plot_margin <- function(
    df,
    truth_col       = "true_subtype",
    xgb_match_col   = "xgb_subtype_match",
    gpt_match_col   = "gpt_subtype_match",
    family_fun      = infer_family,  # function: character -> family string
    family_order    = c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither"),
    winner_colors   = c("XGB" = "steelblue", "GPT" = "firebrick", "Tie" = "grey50"),
    base_size       = 20,
    show_family_strips = FALSE
) {
  stopifnot(is.function(family_fun))
  # Build sensitivity data for each model
  sens_long <- dplyr::bind_rows(
    df |>
      dplyr::group_by(truth = .data[[truth_col]]) |>
      dplyr::summarise(
        correct = sum(.data[[xgb_match_col]], na.rm = TRUE),
        total   = sum(!is.na(.data[[xgb_match_col]])),
        .groups = "drop"
      ) |>
      dplyr::mutate(model = "XGB"),
    df |>
      dplyr::group_by(truth = .data[[truth_col]]) |>
      dplyr::summarise(
        correct = sum(.data[[gpt_match_col]], na.rm = TRUE),
        total   = sum(!is.na(.data[[gpt_match_col]])),
        .groups = "drop"
      ) |>
      dplyr::mutate(model = "GPT")
  ) |>
    dplyr::filter(.data$total > 0) |>
    dplyr::mutate(
      sensitivity = .data$correct / .data$total,
      family      = purrr::map_chr(.data$truth, family_fun)
    )
  
  # Compute winner margin: XGB - GPT
  winner_df <- sens_long |>
    dplyr::select(truth, model, sensitivity, family) |>
    tidyr::pivot_wider(names_from = .data$model, values_from = .data$sensitivity) |>
    dplyr::mutate(
      diff   = .data$XGB - .data$GPT,
      winner = dplyr::case_when(
        .data$diff > 0 ~ "XGB",
        .data$diff < 0 ~ "GPT",
        TRUE           ~ "Tie"
      )
    )
  
  # Order subtypes by family then abs(diff)
  winner_df <- winner_df |>
    dplyr::mutate(family = factor(.data$family, levels = family_order)) |>
    dplyr::group_by(.data$family) |>
    dplyr::arrange(dplyr::desc(abs(.data$diff)), .by_group = TRUE) |>
    dplyr::mutate(truth = factor(.data$truth, levels = rev(unique(.data$truth)))) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      label_txt = paste0(round(.data$diff * 100), "%"),
      hjust_lab = dplyr::if_else(.data$diff > 0, -0.3, 1.3)
    )
  
  # X-axis limits with a bit of padding around min/max
  min_d <- min(winner_df$diff, na.rm = TRUE)
  max_d <- max(winner_df$diff, na.rm = TRUE)
  pad   <- 0.05
  x_min <- if (is.finite(min_d)) min(min_d - pad, -pad) else -pad
  x_max <- if (is.finite(max_d)) max(max_d + pad,  pad) else  pad
  
  p <- ggplot2::ggplot(winner_df, ggplot2::aes(x = .data$diff, y = .data$truth, fill = .data$winner)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = .data$label_txt, hjust = .data$hjust_lab),
                       color = "black", size = 5) +
    ggplot2::scale_fill_manual(values = winner_colors, guide = "none") +
    ggplot2::geom_vline(xintercept = 0, color = "black") +
    ggplot2::scale_x_continuous(
      labels = scales::percent_format(accuracy = 1),
      limits = c(x_min, x_max)
    ) +
    ggplot2::facet_grid(family ~ ., scales = "free_y", space = "free_y") +
    ggplot2::labs(
      title = "Winner Margin by Subtype",
      subtitle = NULL,
      x = "Difference in Sensitivity (XGB − GPT)",
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      axis.text.y        = ggplot2::element_text(color = "black"),
      axis.title.y       = ggplot2::element_text(color = "black"),
      axis.ticks.y       = ggplot2::element_line(color = "black"),
      panel.grid.major.y = ggplot2::element_blank(),
      strip.text.y       = if (show_family_strips) ggplot2::element_text() else ggplot2::element_blank()
    )
  
  return(p)
}

