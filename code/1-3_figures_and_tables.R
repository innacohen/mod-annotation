
# IMPORT FUNCTIONS --------------------------------------------------------
source("code/_utils.R")


library(stringr)

clean_gpt_pred <- function(gpt_pred, true_subtype) {
  ifelse(
    str_detect(gpt_pred, fixed(true_subtype)),
    true_subtype,
    "Z Neither"
  )
}


# IMPORT DATA -------------------------------------------------------------
shap_df = read_csv("data/pipeline/predictions_with_shap.csv") 
gpt_run1 = read_excel("data/gpt/gpt_baseline_run1.xlsx") %>% rename(gpt_run1 = mechanisms,gpt_run1_notes = notes)
gpt_run2 = read_excel("data/gpt/gpt_baseline_run2.xlsx") %>% rename(gpt_run2 = mechanisms, gpt_run2_notes = notes)
gpt_mini = read_excel("data/gpt/gpt_mini.xlsx")  %>% rename(gpt_mini = mechanisms,gpt_mini_notes = notes) 
gpt_mini_h = read_excel("data/gpt/gpt_mini_with_heuristics.xlsx") %>% rename(gpt_mini_h = mechanisms, gpt_mini_h_notes = notes)
gpt_h = read_excel("data/gpt/gpt_with_heuristics.xlsx")  %>% rename(gpt_h = mechanisms, gpt_h_notes = notes) 


xgb_pred_df = shap_df %>%
  select(file_hash, xgb_pred_type, xgb_pred_subtype, xgb_pred_prob, true_subtype, true_type) %>%
  rename(hash = file_hash)


gpt_df = gpt_run1 %>% 
  left_join(gpt_run2, by="hash") %>%
  left_join(gpt_h, by="hash") %>%
  left_join(gpt_mini, by="hash") %>%
  left_join(gpt_mini_h, by="hash") 


pred_df2 = xgb_pred_df %>%
  inner_join(gpt_df, by="hash") %>%
  mutate(gpt_run1_clean = ifelse(str_detect(gpt_run1, fixed(true_subtype)), true_subtype, "Z Neither"))


pred_df2 %>%
  filter(str_detect(gpt_run1, ",")) %>%
  View()

# TABLE 1 -----------------------------------------------------------------

ant_df = read_csv("data/pipeline/split_df2_with_labels.csv") %>%  
  mutate(set = factor(set, levels=c("train","val","test"), labels=c("Train","Validation","Test")))


label(ant_df$type) = "Type"
label(ant_df$label) = "Subtype"


t1 = table1(~type+label |set, data=ant_df, overall=F, extra.col=list(`P-value`=pvalue))

# list of tables and the doc
my_list <- list(df1 <- t1flex(t1))

my_doc <- read_docx()
walk(my_list, write_word_table, my_doc) 
fname = paste0("../output/mod_file_tables_",Sys.Date(),".docx")
dir.create(dirname(fname), showWarnings = FALSE, recursive = TRUE)
print(my_doc, target = fname) %>% invisible()



# PLOTS  -----------------------------------------
# Compare XGB vs GPT
plot_db(pred_df, 
        col1 = "xgb_pred_subtype", 
        col2 = "gpt_bl_pred_subtype",
        col1_label = "XGB",
        col2_label = "GPT",
        title = "XGB vs GPT Sensitivity")

# Compare two different GPT models
plot_db(pred_df,
        col1 = "gpt_bl_pred_subtype",
        col2 = "gpt_aug_pred_subtype", 
        col1_label = "GPT (no heuristics)",
        col2_label = "GPT (with heuristics)")
