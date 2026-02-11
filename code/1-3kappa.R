
source("code/_utils.R")




# DATA --------------------------------------------------------------------


gpt_run1 = read_excel("data/gpt/gpt_baseline_run1.xlsx") %>% rename(gpt_run1 = mechanisms, gpt_run1_notes = notes)
gpt_run2 = read_excel("data/gpt/gpt_baseline_run2.xlsx") %>% rename(gpt_run2 = mechanisms, gpt_run2_notes = notes)
gpt_mini = read_excel("data/gpt/gpt_mini.xlsx")  %>% rename(gpt_mini = mechanisms, gpt_mini_notes = notes) 
gpt_mini_h = read_excel("data/gpt/gpt_mini_with_heuristics.xlsx") %>% rename(gpt_mini_h = mechanisms, gpt_mini_h_notes = notes)
gpt_h = read_excel("data/gpt/gpt_with_heuristics.xlsx")  %>% rename(gpt_h = mechanisms, gpt_h_notes = notes) 
ant_df = read_csv("data/pipeline/split_df2_with_labels.csv")

confidence_df = read_excel("annotations/model_db_annotations_og.xlsx") %>%
  select(file_hash, subtype_confidence) %>%
  drop_na(file_hash, subtype_confidence) %>%
   rename(old_subtype_confidence = subtype_confidence) 

old_inna_notes = read_excel("annotations/model_db_annotations_og.xlsx") %>%
  select(file_hash, notes_free_text) %>%
  rename(old_inna_notes = notes_free_text) %>%
  drop_na()

curr_inna_notes = read_excel("annotations/model_db_annotations.xlsx") %>%
  select(file_hash, notes_free_text) %>%
  rename(curr_inna_notes = notes_free_text) %>%
  drop_na()

all_inna_notes = old_inna_notes %>%
  full_join(curr_inna_notes, by="file_hash") %>%
  rename(hash = file_hash)


url = read_excel("annotations/model_db_annotations.xlsx") %>%
  select(file_hash, url) %>%
  rename(hash = file_hash) %>%
  drop_na()

ant_df2 = ant_df %>%
  left_join(confidence_df, by="file_hash") %>%
  mutate(old_subtype_confidence = case_when(file_hash == "0f584fb339c5a5f1dba99b492aa6efe819651643cc39676e216dc9e5e53e2b19" ~ "3 - Highly confident",
                                           TRUE ~ old_subtype_confidence))  %>%
  rename(hash = file_hash)


pred_df = read_csv("data/pipeline/predictions.csv")

xgb_pred_df = pred_df %>%
  select(file_hash, xgb_pred_type, xgb_pred_subtype) %>%
  rename(hash = file_hash)



# 5K AGREEMENT ACROSS ALL RUNS -----------------------------------------------

df = gpt_run1 %>% 
    left_join(gpt_run2, by="hash") %>%
    left_join(gpt_h, by="hash") %>%
    left_join(gpt_mini, by="hash") %>%
    left_join(gpt_mini_h, by="hash") 
    


gpt_cols <- c("gpt_run1", "gpt_run2", "gpt_h", "gpt_mini", "gpt_mini_h")

pairwise_results <- pairwise_kappa(df, gpt_cols)


df2 <- df %>%
  mutate(across(all_of(gpt_cols), replace_multiple_preds))

pairwise_results <- pairwise_kappa(df2, gpt_cols)

#df2 %>%
#  filter(gpt_run1 != gpt_run2) %>%
#  select(gpt_run1, gpt_run2) %>%
#  View()


all_disagree_plots <- plot_all_top_disagreements(df, gpt_cols, top_n = 20)

all_disagree_plots[["gpt_run1_vs_gpt_mini"]]


# 1K AGREEMENT --------------------------------------------------------

df3 = ant_df2 %>%
  left_join(df2, by="hash") %>%
  mutate(gpt55_agree = gpt_run1 == gpt_run2) %>% 
  mutate(gpt5m_agree = gpt_run1 == gpt_mini) %>%
  mutate(gpt_mh_agree = gpt_mini == gpt_mini_h) %>%
  mutate(gpt_5h_agree = gpt_run1 == gpt_h) %>%
  mutate(human_high_confidence = old_subtype_confidence == "3 - Highly confident") %>%
  drop_na() %>%
  mutate(across(c(ends_with("_agree"), human_high_confidence), factor_tf))
  
t1 = table1(~human_high_confidence | gpt55_agree, data=df3, caption="Columns: GPT run 1 == GPT run2")
t2 = table1(~human_high_confidence | gpt5m_agree, data=df3, caption= "Columns: GPT run 1 == GPT mini" )
t3 = table1(~human_high_confidence | gpt_mh_agree, data=df3, caption = "Columns: GPT mini == GPT mini_h")
t4 = table1(~human_high_confidence | gpt_5h_agree, data=df3, caption = "Columns: GPT run 1 == GPT_h")
t5 = table1(~gpt55_agree | human_high_confidence, data=df3, caption="Columns: Human High Confidence")
t6 = table1(~gpt5m_agree | human_high_confidence, data=df3, caption= "Columns: Human High Confidence" )
t7 = table1(~gpt_mh_agree | human_high_confidence, data=df3, caption = "Columns: Human High Confidence")
t8= table1(~gpt_5h_agree | human_high_confidence, data=df3, caption = "Columns: Human High Confidence")

delta_df <- df3 %>%
  select(human_high_confidence, gpt55_agree, gpt5m_agree, gpt_mh_agree, gpt_5h_agree) %>%
  pivot_longer(
    cols = starts_with("gpt"),
    names_to = "comparison",
    values_to = "agree"
  ) %>%
  group_by(comparison, human_high_confidence) %>%
  summarise(
    n = n(),
    agree_rate = mean(agree == "TRUE"),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = human_high_confidence,
    values_from = c(n, agree_rate),
    names_sep = "_"
  ) %>%
  mutate(
    # TRUE = high confidence, FALSE = not high confidence
    delta_pp = 100 * (agree_rate_TRUE - agree_rate_FALSE)
  )

delta_df %>%
  mutate(
    comparison = recode(
      comparison,
      gpt55_agree = "GPT run1 vs run2",
      gpt5m_agree = "GPT run1 vs mini",
      gpt_mh_agree = "GPT mini vs mini+heuristic",
      gpt_5h_agree = "GPT run1 vs heuristic"
    )
  ) %>%
  ggplot(aes(x = comparison, y = delta_pp)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Δ Agreement by Human Confidence",
    subtitle = "Agreement rate difference (High confidence − Not high confidence)",
    x = NULL,
    y = "Δ Agreement (percentage points)"
  ) +
  theme_minimal(base_size = 14)

delta_df_labeled <- delta_df %>%
  mutate(
    comparison = recode(
      comparison,
      gpt55_agree = "GPT run1 vs run2",
      gpt5m_agree = "GPT run1 vs mini",
      gpt_mh_agree = "GPT mini vs mini+heuristic",
      gpt_5h_agree = "GPT run1 vs heuristic"
    ),
    label = paste0(
      round(100 * agree_rate_TRUE, 1), "% vs ",
      round(100 * agree_rate_FALSE, 1), "%"
    )
  )

ggplot(delta_df_labeled, aes(x = comparison, y = delta_pp)) +
  geom_col() +
  geom_text(aes(label = label), hjust = -0.05, size = 4) +
  coord_flip() +
  labs(
    title = "Δ Agreement by Human Confidence",
    subtitle = "High confidence − Not high confidence",
    x = NULL,
    y = "Δ Agreement (percentage points)"
  ) +
  ylim(min(delta_df_labeled$delta_pp) - 1, max(delta_df_labeled$delta_pp) + 3) +
  theme_minimal(base_size = 14)

rr_df <- df3 %>%
  select(human_high_confidence, gpt55_agree, gpt5m_agree, gpt_mh_agree, gpt_5h_agree) %>%
  pivot_longer(
    cols = starts_with("gpt"),
    names_to = "comparison",
    values_to = "agree"
  ) %>%
  mutate(
    # outcome: disagreement
    disagree = (agree == "FALSE"),
    # exposure group: NOT high confidence
    not_high = (human_high_confidence == "FALSE")
  ) %>%
  group_by(comparison) %>%
  summarise(
    # counts for 2x2
    a = sum(disagree & not_high),        # Disagree among NotHigh
    b = sum(!disagree & not_high),       # Agree among NotHigh
    c = sum(disagree & !not_high),       # Disagree among High
    d = sum(!disagree & !not_high),      # Agree among High
    .groups = "drop"
  ) %>%
  mutate(
    risk_not_high = a / (a + b),
    risk_high     = c / (c + d),
    RR = risk_not_high / risk_high,
    
    # log(RR) CI (Wald)
    se_logRR = sqrt( (1/a) - (1/(a+b)) + (1/c) - (1/(c+d)) ),
    logRR = log(RR),
    CI_low  = exp(logRR - 1.96 * se_logRR),
    CI_high = exp(logRR + 1.96 * se_logRR)
  )

rr_df



rr_df_plot <- rr_df %>%
  mutate(
    comparison = recode(
      comparison,
      gpt55_agree = "GPT run1 vs run2",
      gpt5m_agree = "GPT run1 vs mini",
      gpt_mh_agree = "GPT mini vs mini+heuristic",
      gpt_5h_agree = "GPT run1 vs heuristic"
    )
  )

ggplot(rr_df_plot, aes(x = RR, y = comparison)) +
  geom_vline(xintercept = 1, linetype = "dashed") +
  geom_errorbarh(aes(xmin = CI_low, xmax = CI_high), height = 0.2) +
  geom_point(size = 3) +
  scale_x_log10() +
  labs(
    title = "Risk Ratio of Disagreement by Human Confidence",
    subtitle = "RR = P(Disagree | Not high confidence) / P(Disagree | High confidence)",
    x = "Risk Ratio (log scale)",
    y = NULL
  ) +
  theme_minimal(base_size = 14)


pairwise_results <- pairwise_kappa(df3, gpt_cols)




# ERROR ANALYSIS ----------------------------------------------------------

df4 = xgb_pred_df %>%
  left_join(df3, by="hash") %>%
  mutate(
    gpt_correct  = (gpt_run1 == label),
    mini_correct = (gpt_mini == label),
    xgb_correct  = (xgb_pred_subtype == label),
    
    gpt_wrong  = !gpt_correct,
    mini_wrong = !mini_correct,
    xgb_wrong  = !xgb_correct
  )

overlap3 <- df4 %>%
  count(gpt_wrong, mini_wrong, xgb_wrong) %>%
  mutate(pct = n / sum(n)) %>%
  arrange(desc(n))


# NOTES ANALYSIS ----------------------------------------------------------

#Where XGBoost is right but others are wrong
xgb_correct = df4 %>%
  filter(xgb_correct == T & gpt_wrong == T & mini_wrong == T) 

extra_cols = c("hash", setdiff(names(xgb_correct), names(df)))

xgb2 = xgb_correct %>%
  select(all_of(extra_cols)) %>%
  left_join(df, by="hash") %>%
  left_join(all_inna_notes, by="hash") %>%
  left_join(url, by="hash")


#look at gpt 5
xgb3 = xgb2 %>%
  select(url, label, gpt_run1, gpt_run1_notes, old_inna_notes, old_subtype_confidence) 


gpt_mini_wrong = df4 %>%
  filter(gpt_wrong == F & mini_wrong == T) 


# Combine tables into a single HTML document
html_output <- paste(
  "<html>",
  "<head>",
  "<style>",
  "body { font-family: Arial, sans-serif; margin: 20px; }",
  "table { border-collapse: collapse; margin: 20px 0; width: 100%; }",
  "th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }",
  "th { background-color: #f2f2f2; }",
  "h2 { margin-top: 30px; }",
  "</style>",
  "</head>",
  "<body>",
  t1,
  t2,
  t3,
  t4,
  t5,
  t6,
  t7,
  t8,
  "</body>",
  "</html>",
  sep = "\n"
)

# Save HTML file
fname <- paste0("output/confidence_tables_", Sys.Date(), ".html")
writeLines(html_output, fname)
