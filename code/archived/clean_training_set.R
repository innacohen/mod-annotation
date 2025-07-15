library(readxl)
library(tidyverse)
library(janitor)
library(data.table)

fp = "/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/model_db_annotations.xlsx"
raw_df = read_excel(fp)
raw_vocab_df = read_excel(fp, sheet = "ref")

vocab_df = raw_vocab_df %>%
  select(names(raw_vocab_df)[1:5])

train_df = raw_df %>%
  filter(annotated == "y" & ask_robert == "n")

#We need to exclude some of the controlled vocabulary because we didn't have examples of them in our training data
a = vocab_df$alias
b = unique(unlist(train_df[, c("subtype_1", "subtype_2", "subtype_3", "subtype_4")]))
excluded_vocab = setdiff(a,b)
paste("Excluding the following")
print(excluded_vocab)

vocab_df2 = vocab_df %>%
  filter(!alias %in% excluded_vocab)

# Create label_df with a "label" column
label_df <- vocab_df2 %>%
  column_to_rownames(var = "alias") %>%  # Make 'alias' column the row names
  t() %>%  # Transpose
  as_tibble(rownames = NA) %>%  # Convert back to tibble
  clean_names() %>%
  names() %>%  # Extract names as a vector
  tibble(label = .)  # Convert vector into a tibble with a "label" column

vocab_df3 = vocab_df2 %>%
          bind_cols(label_df) 

View(vocab_df3)
lookup_values = setNames(vocab_df3$label, vocab_df3$alias)

train_df_wide = train_df %>%
  mutate(across(c(subtype_1, subtype_2, subtype_3, subtype_4), ~ recode(., !!!lookup_values)))

fname = "/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/annotations_wide.csv"

fwrite(train_df_wide, fname)


train_df_long = train_df_wide %>%
  pivot_longer(cols = subtype_1:subtype_4, names_to = "subtype", values_to = "label") %>%
  drop_na(label) 

fname = "/gpfs/gibbs/project/mcdougal/imc33/mod-extract/data/annotations_long.csv"

fwrite(train_df_long, fname)

View(train_df_long)
