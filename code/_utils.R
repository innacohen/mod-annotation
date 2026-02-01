

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




# KAPPA FUNCTIONS ---------------------------------------------------------

pairwise_kappa <- function(df, cols, weight = "unweighted") {
  pairs <- combn(cols, 2, simplify = FALSE)
  
  purrr::map_dfr(pairs, function(p) {
    
    x <- df %>%
      dplyr::select(dplyr::all_of(p)) %>%
      tidyr::drop_na()
    
    out <- irr::kappa2(x, weight = weight)
    
    disagree_n <- sum(x[[p[1]]] != x[[p[2]]])
    agree_n <- sum(x[[p[1]]] == x[[p[2]]])
    
    tibble::tibble(
      rater1     = p[1],
      rater2     = p[2],
      n          = nrow(x),
      agree_n    = agree_n,
      disagree_n = disagree_n,
      disagree_pct = disagree_n / nrow(x),
      kappa      = unname(out$value),
      z          = unname(out$statistic),
      p_value    = out$p.value
    )
  }) %>%
    dplyr::arrange(dplyr::desc(kappa))
}

replace_multiple_preds <- function(x, multiple_label = "Multiple") {
  x <- trimws(x)
  
  dplyr::if_else(
    is.na(x), NA_character_,
    dplyr::if_else(grepl(",", x), multiple_label, x)
  )
}


plot_disagreement_heatmap <- function(df, a, b, top_n = 30) {
  
  tab <- df %>%
    select(all_of(c(a, b))) %>%
    drop_na() %>%
    count(.data[[a]], .data[[b]], name = "n") %>%
    mutate(disagree = .data[[a]] != .data[[b]]) %>%
    filter(disagree)
  
  # keep top disagreements for readability
  tab_top <- tab %>% slice_max(n, n = top_n)
  
  ggplot(tab_top, aes(x = .data[[b]], y = .data[[a]], fill = n)) +
    geom_tile() +
    geom_text(aes(label = n), size = 3) +
    labs(
      title = paste("Disagreements:", a, "vs", b),
      x = b,
      y = a
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

plot_top_disagreements <- function(df, a, b, top_n = 20) {
  dd <- df %>%
    select(hash, all_of(c(a, b))) %>%
    drop_na() %>%
    filter(.data[[a]] != .data[[b]]) %>%
    mutate(pair = paste0(.data[[a]], "  →  ", .data[[b]])) %>%
    count(pair, sort = TRUE) %>%
    slice_head(n = top_n)
  
  ggplot(dd, aes(x = reorder(pair, n), y = n)) +
    geom_col() +
    coord_flip() +
    labs(
      title = paste("Top disagreements:", a, "vs", b),
      x = "Disagreement (A → B)",
      y = "Count"
    ) +
    theme_minimal()
}

get_disagreements <- function(df, a, b, extra_cols = c("file_hash", "hash")) {
  df %>%
    select(any_of(extra_cols), all_of(c(a, b))) %>%
    drop_na() %>%
    filter(.data[[a]] != .data[[b]])
}

plot_all_top_disagreements <- function(df, cols, top_n = 20) {
  pairs <- combn(cols, 2, simplify = FALSE)
  
  plots <- purrr::map(pairs, function(p) {
    plot_top_disagreements(df, a = p[1], b = p[2], top_n = top_n)
  })
  
  names(plots) <- purrr::map_chr(pairs, ~ paste0(.x[1], "_vs_", .x[2]))
  plots
}



plot_all_top_disagreements_faceted <- function(df, cols, top_n = 10) {
  
  pairs <- combn(cols, 2, simplify = FALSE)
  
  dd <- purrr::map_dfr(pairs, function(p) {
    a <- p[1]; b <- p[2]
    
    df %>%
      select(all_of(c(a, b))) %>%
      drop_na() %>%
      filter(.data[[a]] != .data[[b]]) %>%
      mutate(pair = paste0(a, " vs ", b),
             mismatch = paste0(.data[[a]], " → ", .data[[b]])) %>%
      count(pair, mismatch, sort = TRUE) %>%
      slice_head(n = top_n)
  })
  
  ggplot(dd, aes(x = reorder_within(mismatch, n, pair), y = n)) +
    geom_col() +
    coord_flip() +
    scale_x_reordered() +
    facet_wrap(~ pair, scales = "free_y") +
    theme_minimal() +
    labs(
      title = "Top disagreements across all GPT head-to-head comparisons",
      x = "Mismatch (A → B)",
      y = "Count"
    )
}

factor_tf <- function(x) {
  factor(x, levels = c(TRUE, FALSE), labels = c("TRUE", "FALSE"))
}

