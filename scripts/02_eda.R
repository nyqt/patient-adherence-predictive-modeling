# this file contains the new dataset exploration 

# ==============================================================================
# 1. SETUP, LIBRARIES, & DATA IMPORT -----------------------------------------
# ==============================================================================

library(readr)
library(dplyr)
library(ggplot2)
library(reshape2)

# Load split datasets from data_preprocessing into the new script
patient_train <- readRDS("data/train_data.rds")
patient_test  <- readRDS("data/test_data.rds")

# check to make sure they loaded correctly
print(nrow(patient_train))
print(nrow(patient_test))


# ==============================================================================
# 2. HIGH-LEVEL DATA AUDIT ----------------------------------------------------
# ==============================================================================
# check for nulll values
colSums(is.na(patient_train))

# ==============================================================================
# 3. TARGET VARIABLE DISTRIBUTION ---------------------------------------------
# ==============================================================================
# check percent of adherent/non-adherent
patient_train %>%
  count(adherent_binary, name = "Count") %>%
  mutate(Percentage = round((Count / sum(Count)) * 100, digits = 2))

# ==============================================================================
# 4. NUMERIC FEATURE EXPLORATION ----------------------------------------------
# ==============================================================================
# visualize each variable and check for correlation

# plot all columns in the training dataset except patient
columns_plot <- for (col_name in names(patient_train)) {
  
  if (col_name == "patient") next
  col_data <- patient_train[[col_name]]
  
  if (is.factor(col_data) || is.character(col_data)) {
    tab <- table(col_data)
    
    if (length(tab) <= 1) {
      next
    }
    
    barplot(
      tab,
      main = paste("Barplot of", col_name),
      ylab = "Count",
      col = "steelblue"
    )
    
  } else if (is.numeric(col_data)) {
    hist(
      col_data,
      main = paste("Histogram of", col_name),
      xlab = col_name,
      col = "steelblue",
      border = "white"
    )
  }
}


# heatmap of predictors
num_vars <- sapply(patient_train, is.numeric)
df_num <- patient_train[, num_vars]

corr_mat <- cor(df_num, use = "pairwise.complete.obs")

corr_melt <- melt(corr_mat)

num_predictors_heatmap <- ggplot(corr_melt, aes(Var1, Var2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(low = "steelblue", high = "orange", mid = "white",
                       midpoint = 0, limit = c(-1, 1)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Heatmap of Numeric Predictors",
       x = "", y = "")
num_predictors_heatmap
