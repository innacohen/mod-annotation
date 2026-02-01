
# IMPORT FUNCTIONS --------------------------------------------------------
source("code/_utils.R")


# IMPORT DATA -------------------------------------------------------------
pred_df = read_csv("data/pipeline/predictions.csv") 



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
