source("code/_utils.R")
pred_df <- read_csv("data/pipeline/predictions.csv")


# TABLE 1 -----------------------------------------------------------------

ant_df = read_csv("data/pipeline/split_df2_with_labels.csv") %>%  
  mutate(set = factor(set, levels=c("train","val","test"), labels=c("Train","Validation","Test")))


label(ant_df$type) = "Type"
label(ant_df$label) = "Subtype"


t1 = table1(~type+label |set, data=ant_df, overall=F, extra.col=list(`P-value`=pvalue))

# list of tables and the doc
my_list <- list(df1 <- t1flex(t1))

#my_doc <- read_docx()
#walk(my_list, write_word_table, my_doc) 
#fname = paste0("../output/mod_file_tables_",Sys.Date(),".docx")
#dir.create(dirname(fname), showWarnings = FALSE, recursive = TRUE)
#print(my_doc, target = fname) %>% invisible()


# TABLE 2 --------------------------------------


type_long <- pred_df %>%
  select(file_hash, true_type, ends_with("_pred_type")) %>%
  pivot_longer(
    cols = -c(file_hash, true_type),
    names_to = "model",
    values_to = "pred_type"
  ) %>%
  mutate(model = case_when(
    model == "xgb_pred_type" ~ "XGB",
    model == "gpt_bl_pred_type" ~ "GPT-5.2",
    model == "gpt_h_pred_type" ~ "GPT-5.2 + heuristics",
    model == "gpt_mini_pred_type" ~ "GPT-mini",
    model == "gpt_mini_h_pred_type" ~ "GPT-mini + heuristics"
  )) %>%
  mutate(
    true_type = factor(true_type),
    pred_type = factor(pred_type, levels = levels(true_type))
  ) 


type_metrics <- type_long %>%
  group_by(model) %>%
  summarise(
    Accuracy  = accuracy_vec(true_type, pred_type),
    Precision = precision_vec(true_type, pred_type, estimator="macro"),
    Recall    = recall_vec(true_type, pred_type, estimator="macro"),
    F1        = f_meas_vec(true_type, pred_type, estimator="macro")
  )


type_metrics
subtype_long <- pred_df %>%
  select(file_hash, true_subtype, ends_with("_pred_subtype")) %>%
  pivot_longer(
    cols = -c(file_hash, true_subtype),
    names_to = "model",
    values_to = "pred_subtype"
  ) %>%
  mutate(model = case_when(
    model == "xgb_pred_subtype" ~ "XGB",
    model == "gpt_bl_pred_subtype" ~ "GPT-5.2",
    model == "gpt_h_pred_subtype" ~ "GPT-5.2 + heuristics",
    model == "gpt_mini_pred_subtype" ~ "GPT-mini",
    model == "gpt_mini_h_pred_subtype" ~ "GPT-mini + heuristics"
  )) %>%
  mutate(
    true_subtype = factor(true_subtype),
    pred_subtype = factor(pred_subtype, levels = levels(true_subtype))
  )

subtype_long %>%
  group_by(model, pred_subtype, true_subtype) %>%
  summarise(n=n()) %>%
  filter(is.na(pred_subtype)) %>%
  View()

subtype_metrics <- subtype_long %>%
  group_by(model) %>%
  summarise(
    Accuracy  = accuracy_vec(true_subtype, pred_subtype),
    Precision = precision_vec(true_subtype, pred_subtype,
                              estimator="macro",
                              na_rm = TRUE),
    Recall    = recall_vec(true_subtype, pred_subtype,
                           estimator="macro",
                           na_rm = TRUE),
    F1        = f_meas_vec(true_subtype, pred_subtype,
                           estimator="macro",
                           na_rm = TRUE)
  )

all_subtypes <- levels(subtype_long$true_subtype)

predicted_classes <- subtype_long %>%
  group_by(model) %>%
  summarise(predicted = list(unique(pred_subtype)))


missing_by_model <- predicted_classes %>%
  rowwise() %>%
  mutate(
    missing_subtypes = list(setdiff(all_subtypes, predicted)),
    n_missing = length(missing_subtypes)
  ) %>%
  select(model, n_missing, missing_subtypes)

subtype_metrics_final <- subtype_metrics %>%
  left_join(
    missing_by_model %>% select(model, n_missing),
    by="model"
  )

library(gt)

library(gt)

gt_type <- type_metrics %>%
  gt() %>%
  fmt_number(
    columns = c(Accuracy, Precision, Recall, F1),
    decimals = 3
  ) %>%
  
  # Bold max in each metric column
  tab_style(
    style = cell_text(weight = "bold"),
    locations = cells_body(
      columns = c(Accuracy, Precision, Recall, F1),
      rows = Accuracy == max(Accuracy) |
        Precision == max(Precision) |
        Recall == max(Recall) |
        F1 == max(F1)
    )
  ) %>%
  
  tab_header(title = "Type Classification Metrics")


gt_type



gt_subtype <- subtype_metrics_final %>%
  gt() %>%
  fmt_number(columns = c(Accuracy, Precision, Recall, F1), decimals = 3) %>%
  
  tab_style(
    style = cell_text(weight = "bold"),
    locations = cells_body(rows = model == best_subtype)
  ) %>%
  
  cols_label(n_missing = "# Failed Subtypes")


gtsave(gt_type, "output/type_metrics.docx")


gtsave(gt_subtype, "output/subtype_metrics.docx")
