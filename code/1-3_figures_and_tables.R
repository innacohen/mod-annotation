


# IMPORT FUNCTIONS --------------------------------------------------------
setwd("project_pi_rm693/imc33/mod-annotation/")
source("code/_utils.R")


# IMPORT DATA -------------------------------------------------------------
dd = read_csv("data/pipeline/feature_dd.csv")
xgb_feat_df = read_csv("data/pipeline/feature_importance_global.csv") 
pred_df = read_csv("data/pipeline/predictions_with_shap.csv") 
ant_excel_df = read_excel("annotations/model_db_annotations.xlsx") %>%
  clean_names() %>%
  filter(row_id <= 1300)
ant_long_df = read_csv("data/pipeline/ant_with_excluded_samples.csv") 
ant_pre_df = read_csv("data/pipeline/preprocessed.csv")
ant_pre_df = read_csv("data/pipeline/preprocessed.csv")
cw_df = read_csv("data/pipeline/crosswalk.csv") %>% select(-type)



# GLOBAL VARIABLES --------------------------------------------------------

TRAIN = cw_df %>%
  filter(split == "train") %>%
  pull(file_hash)

INT_VALIDATION = cw_df %>%
  filter(split == "test") %>%
  pull(file_hash)

EXT_VALIDATION = ant_pre_df %>% 
  select(file_hash, rare_subtype) %>%
  filter(rare_subtype != TRUE) %>%
  filter(!file_hash %in% c(TRAIN, INT_VALIDATION)) %>%
  pull(file_hash)


new_subtype_labels <- ant_pre_df %>%
  filter(file_hash %in% c(TRAIN, INT_VALIDATION, EXT_VALIDATION)) %>%
  select(file_hash, new_subtype_label) 

t1_df = ant_excel_df %>%
  filter(file_hash %in% c(TRAIN, INT_VALIDATION, EXT_VALIDATION)) %>%
  clean_names() %>%
  select(row_id, file_hash, type, subtype_confidence, annotated, notes_free_text, subtype_1) %>% 
  distinct() %>%
  left_join(new_subtype_labels, by="file_hash") %>%
  left_join(cw_df, by="file_hash") %>%
  mutate(split = case_when(split == "train" ~ "Train",
                           split == "test" ~ "Internal Validation",
                           file_hash %in% EXT_VALIDATION ~ "External Validation")) %>%
  mutate(split = factor(split, levels=c("Train","Internal Validation", "External Validation")))

label(t1_df$type) = "Type"
label(t1_df$new_subtype_label) = "Subtype"


t1 = table1(~type+new_subtype_label |split, data= t1_df, overall=F, extra.col=list(`P-value`=pvalue))

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


# PLOTS  -----------------------------------------https://ood-bouchet.ycrc.yale.edu/rnode/a1132u05n01.mghpcc.ycrc.yale.edu/23803/graphics/plot_zoom_png?width=761&height=459------------------
plot_top_features(xgb_feat_df)

plot_db(pred_df, order_by = "sens_xgb", facet_by_family = FALSE)

plot_db(pred_df2, order_by = "abs_delta", facet_by_family = FALSE, labels="minimal")

plot_db(pred_df, order_by = "abs_delta", facet_by_family = FALSE, labels = "full", label_size=4, hjust_winner=-0.27, annotate = "percent", percent_accuracy = 1)

plot_db(pred_df, style = "winner", order_by = "abs_delta", facet_by_family = TRUE)


plot_db(pred_df, style = "winner", order_by = "abs_delta",
        facet_by_family = TRUE, labels = "minimal",
        annotate = "percent", percent_accuracy = 1)


plot_db(pred_df, style = "dumbbell", order_by = "sens_gpt",
        facet_by_family = FALSE, annotate = "counts")

plot_top_features(xgb_feat_df, top_n = 15, base_size=20, legend="minimal")

# print(p)
# ggsave("top_features.png", p, width = 8, height = 5, dpi = 300)

