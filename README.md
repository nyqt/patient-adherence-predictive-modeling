# Predictive Modeling for Diabetic Medication Adherence

## Project Overview

This project focuses on **predicting medical adherence for patients with diabetes**, a critical factor in improving patient quality of life and reducing long-term medical costs. Because the source dataset lacked explicit medication dosage information, a custom adherence metric was engineered based on **prescription pickup consistency**.

[**View the Complete Analysis & R Code Here**](https://github.com/nyqt/patient-adherence-predictive-modeling/blob/main/output/patient_adherence_analysis.md)

## Problem Statement

Medical adherence is defined as the consistency with which patients take their prescribed medication, with a typical clinical goal of at least **80% adherence**. Identifying non-adherent patients allows providers to offer proactive resources, while identifying adherent patients helps rule out inconsistent usage as a cause for unresolved ailments.

## Data Engineering & Preprocessing

The source dataset spanned **473 days** and contained **52,616 transactional records**. To build a patient-level predictive model, the rows were aggregated by unique patient identifiers and processed using the following framework:

-   **Custom Adherence Metric:** Because explicit dosage data was unavailable, adherence was engineered based on prescription pickup consistency. The mean and median number of days between pickups were calculated for all patients with at least two fills.
-   **Target Variable Formulation:** A patient was classified as "Adherent" (**Adherent Binary = 1**) if the difference between their mean and median pickup intervals was **less than 5 days**. This boundary accommodates minor real-world scheduling variations while requiring long-term structural consistency.
-   **Feature Engineering & Selection:** Twelve initial predictors were extracted (including patient age, gender, longitudinal visit counts, and baseline adherence gaps).
-   **Multicollinearity Mitigation:** Highly correlated structural features—such as raw mean gap vs. median gap—were identified via a **correlation heatmap** and systematically removed to ensure coefficient stability in the linear models.

## Modeling Framework

The project evaluated four distinct modeling approaches to balance accuracy with explainability:

1.  **Logistic Regression:** Selected as a **cost-effective and explainable** model. The final version used **AIC stepwise selection**. Visits, adherence score, and number of prescriptions were the most significant predictors.
2.  **Single Decision Tree:** Used to **evaluate data complexity**; the high number of branches justified the use of more complex models.
3.  **Random Forest:** Built as a complex comparison model using 500 trees.
4.  **Gradient Boosting (GBM):** Chosen as the **primary complex model** because it achieved the highest AUC and accuracy scores.

## Evaluation & Performance

Models were evaluated using **AUC (Area Under the Curve)** and **out-of-sample accuracy**.

| Model | In-Sample AUC | Out-of-Sample AUC | Overall Test Accuracy |
|:---|:---|:---|:---|
| **Logistic Regression** | 0.774 | 0.748 | 75.54% |
| **Gradient Boosting** | 0.872 | 0.853 | 79.18% |

## Clinical Implications

The "best" model depends on the clinical objective:

-   **Gradient Boosting** is preferred for maximum predictive **accuracy**.
-   **Logistic Regression** is preferred for **medical explainability**.
-   **Error Analysis:** The models weight all errors equally, but they have different clinical outcomes:
    -   A **False Non-Adherent** prediction can lead to patient frustration due to unfounded assumptions.
    -   A **False Adherent** prediction may leave critical medical discussions unaddressed.

## Technologies Used

-   **Language:** R
-   **Key Libraries:** `dplyr`, `ggplot2`, `caret`, `rpart`, `randomForest`, `gbm`, `pROC`

## How to Reproduce This Analysis

1.  **Clone the Repository:** Clone this repository to your local machine.

2.  **Environment Setup:** Ensure you have R and RStudio installed, then run the following command to install the required dependencies:

    ``` r
    install.packages(c("dplyr", "ggplot2", "caret", "rpart", "randomForest", "gbm", "pROC"))
    ```

## Execution Order

1.  **Open the Project:** Open the RStudio project file (.Rproj) from your main directory.
2.  **Knit the Report:** Open patient_adherence_analysis.Rmd and click the Knit button.
