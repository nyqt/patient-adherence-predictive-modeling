# this file contains the models built for analysis

# ==============================================================================
# 1. SETUP, LIBRARIES, & DATA IMPORT -----------------------------------------
# ==============================================================================

library(readr)
library(dplyr)
library(caret)
library(rpart)        # For the single decision tree
library(rpart.plot)
library(randomForest) # For the random forest
library(gbm)          # For the gradient boosting model

# Load split datasets from data_preprocessing into the new script
patient_train <- readRDS("data/train_data.rds")
patient_test  <- readRDS("data/test_data.rds")

# check to make sure they loaded correctly
print(nrow(patient_train))
print(nrow(patient_test))

# ==============================================================================
# 3. BASELINE LOGISTIC REGRESSION & STEPWISE SELECTION (AIC & BIC) ----------------------------------
# ==============================================================================

# build a logistic regression model with all non-correlated predictors
model_lr1 <- glm(
  adherent_binary ~ age + gender + num_prescriptions + visits + adherence,
  data = patient_train,
  family = binomial
)
summary(model_lr1)


# model of all the predictors
model_full <- glm(
  adherent_binary ~ age + gender + visits + adherence + num_prescriptions,
  data = patient_train,
  family = binomial
)

# model with no predictors
model_null <- glm(
  adherent_binary ~ 1,
  data = patient_train,
  family = binomial
)

# find best BIC model
n <- nrow(patient_train)

best_BIC_model <- step(model_null,
                       scope = formula(model_full),
                       direction = "both",
                       k = log(n),
                       trace = FALSE)

best_BIC_model
BIC(best_BIC_model)



# find best AIC model
best_AIC_model <- step(model_null,
                       scope = formula(model_full),
                       direction = "both",
                       trace = FALSE)

best_AIC_model
AIC(best_AIC_model)


# AIC model has the best AIC score, so it will be the logistic regression 
# model used
model_lr <- best_AIC_model


# ==============================================================================
# 4. SINGLE DECISION TREE ----------------------------------------------------
# ==============================================================================
# tree model to see of a more complex model would be helpful
model_tree <- rpart(
  adherent_binary ~ visits + adherence + num_prescriptions,
  data = patient_train,
  method = "class"
)
rpart.plot(model_tree)

# the numerous branches indicate that a more complex model may be useful

# ==============================================================================
# 5. RANDOM FOREST -----------------------------------------------------------
# ==============================================================================
model_rf <- randomForest(
  factor(adherent_binary) ~ age + gender + visits + adherence + num_prescriptions,
  data = patient_train,
  ntree = 500,
  importance = TRUE
)


# ==============================================================================
# 6. GRADIENT BOOSTING MACHINE (GBM) -----------------------------------------
# ==============================================================================
patient_train_gbm <- subset(patient_train, select = -patient)

model_gbm <- gbm(
  adherent_binary ~ age + gender + visits + adherence + num_prescriptions,
  data = patient_train_gbm,
  distribution = "bernoulli",
  n.trees = 500,
  interaction.depth = 3,
  shrinkage = 0.01
)


# ==============================================================================
# 7. EXPORT ALL TRAINED MODELS -----------------------------------------------
# ==============================================================================
saveRDS(model_lr,     "data/lr_model.rds")
saveRDS(model_tree,   "data/tree_model.rds")
saveRDS(model_rf,      "data/rf_model.rds")
saveRDS(model_gbm,     "data/gbm_model.rds")
