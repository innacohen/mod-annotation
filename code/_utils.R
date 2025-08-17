

# LIBRARIES ---------------------------------------------------------------

library(tidyverse)
library(naniar)
library(table1)
setwd("~/palmer_scratch/mod-extract/code")




# FUNCTIONS ---------------------------------------------------------------


### Render p-value
# Concise output for followup table (only Yes's, instead of Yes/No)
#Show the mean (SD) and median (IQR) for continuous variables
pvalue <- function(x, ...) {
  # Construct vectors of data y, and groups (strata) g
  y <- unlist(x)
  g <- factor(rep(1:length(x), times = sapply(x, length)))
  
  if (is.numeric(y)) {
    # For numeric variables with more than two groups, perform a one-way ANOVA
    if (length(unique(g)) > 2) {
      p <- summary(aov(y ~ g))[[1]]["Pr(>F)"][1]
    } else {
      # For exactly two groups, use a t-test
      p <- t.test(y ~ g)$p.value
    }
  } else {
    # For categorical variables, perform a chi-squared test of independence
    p <- chisq.test(table(y, g))$p.value
  }
  
  # Format the p-value without HTML substitution
  c("", format.pval(p, digits = 3, eps = 0.001))
}



# Family inference
infer_family <- function(s) {
  s <- trimws(s)
  if (grepl("^I\\s*Other", s, ignore.case = TRUE)) {
    "Other"
  } else if (grepl("(^R\\b|Receptor)", s, ignore.case = TRUE)) {
    "Receptors"
  } else if (grepl("I\\s*H\\b|Ih\\b|HCN|H-?current", s, ignore.case = TRUE)) {
    "H-Current"
  } else if (grepl("\\bK\\b|Potassium", s, ignore.case = TRUE)) {
    "K"
  } else if (grepl("\\bNa\\b|Sodium", s, ignore.case = TRUE)) {
    "Na"
  } else if (grepl("\\bCa\\b|Calcium", s, ignore.case = TRUE)) {
    "Calcium"
  } else if (grepl("\\bNeither\\b", s, ignore.case = TRUE)) {
    "Neither"
  } else {
    "Other"
  }
}