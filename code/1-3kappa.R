
source("code/_utils.R")

gpt_run1 = read_excel("data/gpt/gpt_baseline_v1.xlsx") %>% rename(gpt_run1 = mechanisms) %>% select(-notes)
gpt_run2 = read_excel("data/gpt/gpt_baseline_v2.xlsx") %>% rename(gpt_run2 = mechanisms) %>% select(-notes)

df = gpt_run1 %>% full_join(gpt_run2, by="hash")


kappa_res <- kappa2(
  df[, c("gpt_run1", "gpt_run2")],
  weight = "unweighted"   # classification, not ordinal
)

kappa_res
