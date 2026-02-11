source("code/_utils.R")

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


# FIGURE 2 --------------------------------------