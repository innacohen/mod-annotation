

# LIBRARIES ---------------------------------------------------------------

library(tidyverse)
library(naniar)
library(table1)
library(janitor)
library(readxl)
library(flextable)
library(officer)
library(here)

# FUNCTIONS ---------------------------------------------------------------

pvalue <- function(x, ...) {
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
    family_fun = infer_family,
    family_order = c("Calcium", "H-Current", "K", "Na", "Receptors", "Other", "Neither"),
    order_by = c("sens_xgb", "sens_gpt", "delta", "abs_delta"),
    facet_by_family = FALSE,
    labels = c("full", "minimal"),
    style = c("dumbbell", "winner"),
    annotate = c("none", "percent", "counts"),
    title = "Subtype Sensitivity: XGB vs GPT",
    subtitle = NULL,
    x_lab = "Sensitivity (TP %)",
    y_lab = NULL,
    xgb_color = "#FFA273",
    gpt_color = "steelblue",
    tie_color = NULL,
    line_color = "#999999",
    point_outline = "#333333",
    base_size = 14,
    # Percent annotation controls
    percent_accuracy = 1,
    label_size = 3,
    hjust_winner = -0.3,
    hjust_loser  =  1.3,
    hjust_tie    = -0.3,
    # Counts annotation controls
    counts_label_size = 3,
    counts_hjust_winner = -0.3,
    counts_hjust_loser  =  1.3,
    counts_hjust_tie    = -0.3,
    counts_nudge_x_winner = 0.01,
    counts_nudge_x_loser  = 0.00,
    counts_nudge_x_tie    = 0.01,
    # Axis domain
    x_min = 0, x_max = 1.0,
    extend_right_if_annotated = 0.10,
    # Tie representation
    tie_offset = NULL
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
  
  # Compute a blended colour for tie legend if not supplied
  if (is.null(tie_color)) {
    # Use scales::colour_ramp to find the midpoint colour between XGB and GPT
    tie_color <- scales::colour_ramp(c(xgb_color, gpt_color))(0.5)
  }
  
  # If tie_offset not provided, derive a small offset based on axis range
  if (is.null(tie_offset)) {
    tie_offset <- (x_max - x_min) * 0.01
  }
  
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
    # Prepare a column that distinguishes ties from model points
    sens_long_with_model_ties <- sens_long %>%
      dplyr::mutate(plot_model = dplyr::if_else(.data$winner == "Tie", "Tie", .data$model))
    
    # Split the data into ties and non‑ties
    tie_points <- sens_long_with_model_ties %>%
      dplyr::filter(.data$winner == "Tie") %>%
      # Keep only one row per subtype/family to avoid duplicate plotting
      dplyr::distinct(!!rlang::sym(truth_col), sensitivity, family)
    non_tie_points <- sens_long_with_model_ties %>%
      dplyr::filter(.data$winner != "Tie")
    
    # Add non‑tie points with fill mapped to model
    p <- p +
      ggplot2::geom_point(
        data = non_tie_points,
        ggplot2::aes(fill = .data$plot_model),
        shape = 21, size = 4, color = point_outline, stroke = 1
      )
    
    # For ties, draw two points offset horizontally to indicate half contributions
    if (nrow(tie_points) > 0) {
      p <- p +
        ggplot2::geom_point(
          data = tie_points,
          ggplot2::aes(x = sensitivity - tie_offset),
          shape = 21, size = 4, fill = xgb_color, color = point_outline, stroke = 1
        ) +
        ggplot2::geom_point(
          data = tie_points,
          ggplot2::aes(x = sensitivity + tie_offset),
          shape = 21, size = 4, fill = gpt_color, color = point_outline, stroke = 1
        )
    }
    
    # Define the fill scale so that ties appear in the legend as a blended colour
    p <- p + ggplot2::scale_fill_manual(
      values = c("XGB" = xgb_color, "GPT" = gpt_color, "Tie" = tie_color),
      breaks = c("XGB", "GPT", "Tie"),
      drop = FALSE,
      name = "Model"
    )
  } else {
    # Winner style
    # Create a named vector for all colours including tie (using blended colour for legend)
    all_colors <- c("GPT" = gpt_color, "XGB" = xgb_color, "Tie" = tie_color)
    
    # Split data into tie and non‑tie subsets
    tie_data <- sens_long %>%
      dplyr::filter(.data$winner == "Tie") %>%
      dplyr::distinct(!!rlang::sym(truth_col), sensitivity, family)
    non_tie <- sens_long %>% dplyr::filter(.data$winner != "Tie")
    
    # Winners (filled with color)
    p <- p +
      ggplot2::geom_point(
        data = dplyr::filter(non_tie, .data$model == .data$winner),
        ggplot2::aes(fill = .data$model),
        shape = 21, size = 4, color = "black", stroke = 1
      )
    
    # Losers (hollow)
    p <- p +
      ggplot2::geom_point(
        data = dplyr::filter(non_tie, .data$model != .data$winner),
        shape = 21, size = 2.5, fill = "white", color = "black", stroke = 0.8
      )
    
    # Ties: draw two points offset horizontally to indicate half contributions
    if (nrow(tie_data) > 0) {
      p <- p +
        ggplot2::geom_point(
          data = tie_data,
          ggplot2::aes(x = sensitivity - tie_offset, fill = "XGB"),
          shape = 21, size = 4, color = "black", stroke = 1
        ) +
        ggplot2::geom_point(
          data = tie_data,
          ggplot2::aes(x = sensitivity + tie_offset, fill = "GPT"),
          shape = 21, size = 4, color = "black", stroke = 1
        )
    }
    
    # Scale that includes all three categories
    p <- p + ggplot2::scale_fill_manual(
      values = all_colors,
      breaks = c("XGB", "GPT", "Tie"),
      drop = FALSE,
      name = "Model"
    )
  }
  
  # --- Annotations (mutually exclusive) ---
  if (annotate == "percent") {
    # Create a dataframe with only the higher sensitivity value per subtype
    winner_sens <- sens_long %>%
      dplyr::group_by(.data[[truth_col]]) %>%
      dplyr::filter(.data$sensitivity == max(.data$sensitivity, na.rm = TRUE)) %>%
      dplyr::slice(1) %>%  # In case of ties, just take one
      dplyr::ungroup()
    
    # Add only the winner label (right side) with bold font
    p <- p +
      ggplot2::geom_text(
        data = winner_sens,
        ggplot2::aes(label = scales::percent(.data$sensitivity, accuracy = percent_accuracy)),
        hjust = hjust_winner,
        size = label_size,
        color = "black",
        fontface = "bold"
      )
  } else if (annotate == "counts") {
    # For counts, show the winner counts with bold text
    winner_counts <- sens_long %>%
      dplyr::group_by(.data[[truth_col]]) %>%
      dplyr::filter(.data$sensitivity == max(.data$sensitivity, na.rm = TRUE)) %>%
      dplyr::slice(1) %>%  # In case of ties, just take one
      dplyr::ungroup()
    
    p <- p +
      ggplot2::geom_text(
        data = winner_counts,
        ggplot2::aes(label = .data$label_counts),
        hjust = counts_hjust_winner,
        size = counts_label_size,
        color = "black",
        nudge_x = counts_nudge_x_winner,
        fontface = "bold"
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

# If you need to read it:
# xgb_feat_df <- read_csv("feature_importance.csv", show_col_types = FALSE)
# If you need to read it:
# xgb_feat_df <- readr::read_csv("feature_importance.csv", show_col_types = FALSE)
plot_top_features <- function(
    xgb_feat_df,
    top_n = 15,
    legend = c("full", "minimal", "none"),
    base_size = 20,
    sim_color = "#FFA273",
    text_color = "steelblue"
) {
  legend <- match.arg(legend)
  
  df_plot <- xgb_feat_df %>%
    dplyr::mutate(
      feature_type = dplyr::if_else(stringr::str_detect(feature, "_simfeat"),
                                    "Simulation-derived", "Text-derived")
    ) %>%
    dplyr::arrange(dplyr::desc(gain)) %>%
    dplyr::slice_head(n = top_n) %>%
    dplyr::mutate(
      feature_label = dplyr::case_when(
        # --- K+ current features ---
        feature == "ik_interval1_time_max_to_90_min_simfeat_na"  ~ "Missing: Max→90% Activation (K⁺)",
        feature == "ik_interval1_time_max_to_90_min_simfeat"     ~ "Max→90% Activation (K⁺)",
        feature == "ik_interval1_time_to_90_max_simfeat_na"      ~ "Missing: Time→90% Activation (K⁺)",
        feature == "ik_interval1_time_to_90_max_simfeat"         ~ "Time→90% Activation (K⁺)",
        feature == "ik_interval1_time_min_to_90_max_simfeat_na"  ~ "Missing: Min→90% Activation (K⁺)",
        feature == "ik_interval1_time_min_to_90_max_simfeat"     ~ "Min→90% Activation (K⁺)",
        feature == "ik_interval2_time_to_90_recovery_simfeat_na" ~ "Missing: Recovery→90% (K⁺)",
        feature == "ik_interval2_time_to_90_recovery_simfeat"    ~ "Recovery→90% (K⁺)",
        feature == "ik_interval1_time_to_90_min_simfeat"         ~ "Time→90% Min (K⁺)",
        feature == "ik_interval1_time_to_90_min_simfeat_na"      ~ "Missing: Time→90% Min (K⁺)",
        
        # --- Na+ current features ---
        feature == "ina_interval1_time_to_90_max_simfeat_na"     ~ "Missing: Time→90% Activation (Na⁺)",
        feature == "ina_interval1_time_to_90_max_simfeat"        ~ "Time→90% Activation (Na⁺)",
        feature == "ina_interval1_time_max_to_90_min_simfeat_na" ~ "Missing: Max→90% Activation (Na⁺)",
        feature == "ina_interval1_time_max_to_90_min_simfeat"    ~ "Max→90% Activation (Na⁺)",
        feature == "ina_interval2_time_to_90_recovery_simfeat"   ~ "Recovery→90% (Na⁺)",
        
        # --- Ca2+ current features ---
        feature == "ica_interval1_time_to_90_max_simfeat_na"     ~ "Missing: Time→90% Activation (Ca²⁺)",
        feature == "ica_interval1_time_to_90_max_simfeat"        ~ "Time→90% Activation (Ca²⁺)",
        feature == "ica_interval1_time_min_to_90_max_simfeat_na" ~ "Missing: Min→90% Activation (Ca²⁺)",
        feature == "ica_interval1_time_min_to_90_max_simfeat"    ~ "Min→90% Activation (Ca²⁺)",
        feature == "ica_interval1_time_max_to_90_min_simfeat"    ~ "Max→90% Activation (Ca²⁺)",
        feature == "ica_interval1_time_max_to_90_min_simfeat_na" ~ "Missing: Max→90% Activation (Ca²⁺)",
        feature == "ica_interval2_time_to_90_recovery_simfeat"   ~ "Recovery→90% (Ca²⁺)",
        feature == "ica_interval2_time_to_90_recovery_simfeat_na"~ "Missing: Recovery→90% (Ca²⁺)",
        
        # --- Voltage feature ---
        feature == "voltage_simfeat_na"                          ~ "Missing: Voltage Response",
        feature == "voltage_simfeat"                             ~ "Voltage Response",
        
        # --- Text-derived binary indicators ---
        feature == "read_e_na_yn"                                ~ "Reads Reversal Potential (E Na⁺)",
        feature == "read_e_ca_yn"                                ~ "Reads Reversal Potential (E Ca²⁺)",
        feature == "has_mg_yn"                                   ~ "Contains Mg²⁺ Block",
        feature == "suffix_yn"                                   ~ "Contains Mechanism Name (suffix)",
        TRUE ~ feature
      ),
      feature_label = forcats::fct_reorder(feature_label, gain)
    )
  
  p <- ggplot2::ggplot(df_plot, ggplot2::aes(x = gain, y = feature_label, fill = feature_type)) +
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
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 14, color = "black"),
      axis.title.y = ggplot2::element_text(size = 16, color = "black"),
      axis.ticks.y = ggplot2::element_line(color = "black"),
      legend.position = if (legend %in% c("minimal", "none")) "none" else "bottom"
    )
  
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
    winner_colors   = c("XGB" = "#FFA273", "GPT" = "steelblue", "Tie" = "grey50"),
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


# Create a logging function 
create_logger <- function() {
  # Initialize empty dataframe
  log_df <- data.frame(
    step = character(),
    n_row = integer(),
    n_hash = integer(), 
    stringsAsFactors = FALSE
  )
  
  # Return a list with the log dataframe and a logging function
  list(
    log = log_df,
    add_entry = function(step_name, data) {
      new_row <- data.frame(
        step = step_name,
        n_row = nrow(data),
        n_hash = n_distinct(data$file_hash, na.rm = TRUE),
        stringsAsFactors = FALSE
      )
      log_df <<- rbind(log_df, new_row)
    },
    get_log = function() {
      return(log_df)
    }
  )
}
