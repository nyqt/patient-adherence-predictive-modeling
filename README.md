---
editor_options: 
  markdown: 
    wrap: sentence
---

# Predictive Modeling for Diabetic Medication Adherence

## Project Overview

This project focuses on **predicting medical adherence for patients with diabetes**, a critical factor in improving patient quality of life and reducing long-term medical costs.
Because the source dataset lacked explicit medication dosage information, a custom adherence metric was engineered based on **prescription pickup consistency**.

## Problem Statement

Medical adherence is defined as the consistency with which patients take their prescribed medication, with a typical clinical goal of at least **80% adherence**.
Identifying non-adherent patients allows providers to offer proactive resources, while identifying adherent patients helps rule out inconsistent usage as a cause for unresolved ailments.

## Data Engineering & Preprocessing

The dataset covers **473 days** and initially contained **52,616 rows** with minimal patient identifiers.
\
\* **Adherence Calculation:** Adherence was determined by calculating the **mean and median number of days between pickups** for patients with at least two fills.\
\* **Target Variable:** A patient was deemed "Adherent" (**Adherent Binary = 1**) if the difference between their mean and median pickup intervals was **less than five days**.
This allowed for minor schedule variations while requiring overall consistency.\
\* **Feature Selection:** Twelve predictors were initially considered, including age, gender, number of visits, and adherence score.\
\* **Multicollinearity:** Highly correlated predictors, including mean gap, median gap, and gap counts, were identified via **heatmap analysis** and removed to ensure model stability.

## Modeling Framework

The project evaluated four distinct modeling approaches to balance accuracy with explainability:\
1.
**Logistic Regression:** Selected as a **cost-effective and explainable** model.
The final version used **AIC stepwise selection**.
Visits, adherence score, and number of prescriptions were the most significant predictors.\
2.
**Single Decision Tree:** Used to **evaluate data complexity**; the high number of branches justified the use of more complex models.\
3.
**Random Forest:** Built as a complex comparison model using 500 trees.\
4.
**Gradient Boosting (GBM):** Chosen as the **primary complex model** because it achieved the highest AUC and accuracy scores.

## Evaluation & Performance

Models were evaluated using **AUC (Area Under the Curve)** and **out-of-sample accuracy**.

| Model | In-Sample AUC | Out-of-Sample AUC | Overall Test Accuracy |
|:---|:---|:---|:---|
| **Logistic Regression** | 0.774 | 0.748 | 75.54% |
| **Gradient Boosting** | 0.872 | 0.853 | 79.18% |

## Clinical Implications

The "best" model depends on the clinical objective: \
\* **Gradient Boosting** is preferred for maximum predictive **accuracy**.\
\* **Logistic Regression** is preferred for **medical explainability**.\
\* **Error Analysis:** The models weight all errors equally, but they have different outcomes.
A **False Non-Adherent** prediction can lead to patient frustration due to unfounded assumptions, while a **False Adherent** prediction may leave critical medical discussions unaddressed.

## Technologies Used

-   **Language:** R
-   **Key Libraries:** `dplyr`, `ggplot2`, `caret`, `rpart`, `randomForest`, `gbm`, `pROC`
