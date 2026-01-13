
# IMPORT FUNCTIONS --------------------------------------------------------
source("code/_utils.R")


# IMPORT DATA -------------------------------------------------------------
dd = read_csv("data/pipeline/feature_dd.csv")
xgb_feat_df = read_csv("data/pipeline/feature_importance_global.csv") 
pred_df = read_csv("data/pipeline/predictions_with_shap.csv") 
ant_df = read_csv("data/pipeline/ant_df.csv")
split_df = read_csv("data/pipeline/split_df2_with_labels.csv") %>% select(file_hash, set)

ant_df2 = ant_df %>%
  left_join(split_df, by="file_hash") %>%
  mutate(set = factor(set, levels=c("train","val","test"), labels=c("Train","Validation","Test")))


label(ant_df2$type) = "Type"
label(ant_df2$label) = "Subtype"


t1 = table1(~type+label |set, data= ant_df2, overall=F, extra.col=list(`P-value`=pvalue))

# list of tables and the doc
my_list <- list(df1 <- t1flex(t1))

my_doc <- read_docx()
walk(my_list, write_word_table, my_doc) 
fname = paste0("../output/mod_file_tables_",Sys.Date(),".docx")
dir.create(dirname(fname), showWarnings = FALSE, recursive = TRUE)
print(my_doc, target = fname) %>% invisible()

# GLOBAL VARIABLES --------------------------------------------------------

names(cw_df)
table(pred_df$true_subtype)

types = c("I Ca (HVA)", "I K (Ca-activated)", "I K (Rare)", "R Glutamate", "I Other (Leak)")
pred_df2 = pred_df %>% dplyr::filter(true_type %in% types)


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
