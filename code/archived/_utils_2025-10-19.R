

# LIBRARIES ---------------------------------------------------------------

library(tidyverse)
library(naniar)
library(table1)
library(janitor)
library(readxl)
library(flextable)
library(officer)
library(here)
library(irr)
library(tidytext)
library(dplyr)
library(tidyr)


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
    xgb_pred_col = "xgb_pred_subtype",
    gpt_pred_col = "gpt_bl_pred_subtype",  # or gpt_aug_pred_subtype
    title = "Subtype Sensitivity: XGB vs GPT",
    xgb_color = "#FFA273",
    gpt_color = "steelblue",
    line_color = "grey70",
    base_size = 14
) {
  
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  
  # ---- compute sensitivity per subtype ----
  sens <- df %>%
    group_by(.data[[truth_col]]) %>%
    summarise(
      sens_xgb = mean(.data[[xgb_pred_col]] == .data[[truth_col]], na.rm = TRUE),
      sens_gpt = mean(.data[[gpt_pred_col]] == .data[[truth_col]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    rename(subtype = !!truth_col) %>%
    arrange(subtype) %>%                     # ✅ alphabetical order
    mutate(subtype = factor(subtype, levels = rev(subtype)))  # top = first alphabetically
  
  # ---- long format for points ----
  sens_long <- sens %>%
    pivot_longer(
      cols = c(sens_xgb, sens_gpt),
      names_to = "model",
      values_to = "sensitivity"
    ) %>%
    mutate(
      model = recode(
        model,
        sens_xgb = "XGB",
        sens_gpt = "GPT"
      )
    )
  
  # ---- plot ----
  ggplot() +
    
    # connecting lines
    geom_segment(
      data = sens,
      aes(
        x = sens_xgb,
        xend = sens_gpt,
        y = subtype,
        yend = subtype
      ),
      color = line_color,
      linewidth = 0.8
    ) +
    
    # points
    geom_point(
      data = sens_long,
      aes(x = sensitivity, y = subtype, fill = model),
      shape = 21,
      size = 4,
      color = "black"
    ) +
    
    scale_fill_manual(
      values = c("XGB" = xgb_color, "GPT" = gpt_color),
      name = "Model"
    ) +
    
    scale_x_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, 1)
    ) +
    
    labs(
      title = title,
      x = "Sensitivity (TP %)",
      y = NULL
    ) +
    
    theme_minimal(base_size = base_size) +
    theme(
      panel.grid.major.y = element_blank(),
      legend.position = "top"
    )
}


plot_arrow <- function(
    df,
    truth_col = "true_subtype",
    gpt_bl_col = "gpt_bl_pred_subtype",
    gpt_aug_col = "gpt_aug_pred_subtype",
    title = "Subtype Sensitivity: GPT Baseline → GPT + Heuristics",
    bl_color = "steelblue",
    aug_color = "#1f4ed8",
    arrow_color = "grey60",
    base_size = 14
) {
  
  library(dplyr)
  library(ggplot2)
  library(scales)
  
  # ---- compute sensitivities ----
  sens <- df %>%
    group_by(.data[[truth_col]]) %>%
    summarise(
      sens_bl  = mean(.data[[gpt_bl_col]]  == .data[[truth_col]], na.rm = TRUE),
      sens_aug = mean(.data[[gpt_aug_col]] == .data[[truth_col]], na.rm = TRUE),
      .groups = "drop"
    ) %>%
    rename(subtype = !!truth_col) %>%
    arrange(subtype) %>%                                   # alphabetical
    mutate(subtype = factor(subtype, levels = rev(subtype)))
  
  # ---- plot ----
  ggplot(sens, aes(y = subtype)) +
    
    # arrows: baseline → augmented
    geom_segment(
      aes(
        x = sens_bl,
        xend = sens_aug,
        yend = subtype
      ),
      arrow = arrow(length = unit(0.18, "cm"), type = "closed"),
      color = arrow_color,
      linewidth = 0.9
    ) +
    
    # baseline points
    geom_point(
      aes(x = sens_bl),
      shape = 21,
      size = 4,
      fill = bl_color,
      color = "black"
    ) +
    
    # augmented points
    geom_point(
      aes(x = sens_aug),
      shape = 21,
      size = 4,
      fill = aug_color,
      color = "black"
    ) +
    
    scale_x_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, 1)
    ) +
    
    labs(
      title = title,
      x = "Sensitivity (TP %)",
      y = NULL
    ) +
    
    theme_minimal(base_size = base_size) +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor.x = element_blank()
    )
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
