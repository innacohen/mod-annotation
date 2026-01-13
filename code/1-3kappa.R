
source("code/_utils.R")


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


# GPT 5.2 AGREEMENT -------------------------------------------------------

gpt_run1 = read_excel("data/gpt/gpt_baseline_run1.xlsx") %>% rename(gpt_run1 = mechanisms) %>% select(-notes)
gpt_run2 = read_excel("data/gpt/gpt_baseline_run2.xlsx") %>% rename(gpt_run2 = mechanisms) %>% select(-notes)
gpt_mini = read_excel("data/gpt/gpt_mini.xlsx")  %>% rename(gpt_mini = mechanisms) %>% select(-notes)
gpt_mini_h = read_excel("data/gpt/gpt_mini_with_heuristics.xlsx") %>% rename(gpt_mini_h = mechanisms) %>% select(-notes)
gpt_h = read_excel("data/gpt/gpt_with_heuristics.xlsx")  %>% rename(gpt_h = mechanisms) %>% select(-notes)


df = gpt_run1 %>% 
    left_join(gpt_run2, by="hash") %>%
    left_join(gpt_h, by="hash") %>%
    left_join(gpt_mini, by="hash") %>%
    left_join(gpt_mini_h, by="hash") 
    


gpt_cols <- c("gpt_run1", "gpt_run2", "gpt_h", "gpt_mini", "gpt_mini_h")

pairwise_results <- pairwise_kappa(df, gpt_cols)

pairwise_results

View(df)
