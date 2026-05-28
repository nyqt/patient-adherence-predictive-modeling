# this file contains raw data exploration and preprocessing 

# ==============================================================================
# 1. SETUP, LIBRARIES, & DATA IMPORT -----------------------------------------
# ==============================================================================

library(readr)
library(dplyr)
library(ggplot2)
library(purrr)
library(lubridate)
library(tidyr)
library(car)
library(psych)
library(caret)

# read in data
diabetes <- read_csv("data/Diabetes_Adherence.csv")

# see the data type in each column
str(diabetes)

# ==============================================================================
# 2. INITIAL CLEANING & BASELINE EDA ----
# ==============================================================================
# Code for fixing dates and removing variables when the column has only one value

# format service date column to date
diabetes$`SERVICE DATE` <- as.Date(diabetes$`SERVICE DATE`, format = "%d/%m/%Y")


# how many dates this dataset covers
oldest <- min(diabetes$`SERVICE DATE`, na.rm = TRUE)
newest <- max(diabetes$`SERVICE DATE`, na.rm = TRUE)

days_covered <- newest - oldest
days_covered

# dimensions of the dataframe
dim(diabetes) 


# column names
names(diabetes)


# removes columns with only 1 value
diabetes <- diabetes[, sapply(diabetes, function(x) length(unique(x)) > 1)]

# check data
summary(diabetes)


# confirm dimensions
dim(diabetes)


# function to organize data based on provider and calculate how many patients
# have 1 prescription and how many have more than 1 prescription
provider_summary <- function(df) {
  df %>%
    group_by(PROVIDER, MEMBER) %>%
    summarize(num_prescriptions = n(), .groups = "drop") %>%
    mutate(
      one_rx = num_prescriptions == 1,
      more_than_one_rx = num_prescriptions > 1
    ) %>%
    group_by(PROVIDER) %>%
    summarize(
      patients_one_rx = sum(one_rx),
      patients_more_than_one_rx = sum(more_than_one_rx),
      total_patients = n(),
      percent_more_than_one = patients_more_than_one_rx / total_patients,
      percent_one_rx = patients_one_rx / total_patients,
      .groups = "drop"
    ) %>%
    arrange(desc(percent_more_than_one))
}

# run function provider_summary on data
provider_summary(diabetes)



# how many providers have more than half their patients with more than 
# 1 prescription
num_providers <- provider_summary(diabetes) %>%
  filter(percent_one_rx <= 0.50) %>%
  nrow()
num_providers

# number of distinct providers
distinct_num_of_providers <- n_distinct(diabetes$PROVIDER)

# ratio of total providers to number of distinct providers
num_providers / distinct_num_of_providers


# function to compare number of pickups to adherence score to see if they are
# the same
pickup_adherence_summary <- function(df) {
  
  patient_pickups <- df %>%
    group_by(`PZTIQNT NZXQ`, `SERVICE DATE`) %>% 
    summarize(pickup_event = 1, .groups = "drop") %>% 
    group_by(`PZTIQNT NZXQ`) %>%
    summarize(
      total_pickups = n(),
      .groups = "drop"
    )
  
  patient_adherence <- df[, c("PZTIQNT NZXQ", "ADHERENCE")]
  patient_adherence <- unique(patient_adherence)
  
  combined <- merge(patient_pickups, patient_adherence,
                    by = "PZTIQNT NZXQ",
                    all.x = TRUE)
  
  combined$match <- combined$total_pickups == combined$ADHERENCE
  
  match_summary <- data.frame(
    num_matches = sum(combined$match, na.rm = TRUE),
    num_non_matches = sum(!combined$match, na.rm = TRUE)
  )
  
  list(
    patient_level = combined,
    num_matches     = match_summary$num_matches,
    num_non_matches = match_summary$num_non_matches
    
  )
}


# run function pickup_adherence_summary on data
results <- pickup_adherence_summary(diabetes)

# view the top rows
head(results$patient_level)

# find the total, the percent of matches and the percent of non-matches
total = results$num_matches + results$num_non_matches	
percentage_of_matching = results$num_matches / total
percentage_not_matching = results$num_non_matches / total

# total number of pickups
total

# percent where the the adherence and percentage of pickups matched
percentage_of_matching

# percent where the the adherence and percentage of pickups did not match
percentage_not_matching  



# view the values in the adherence column
distinct_adherence_values <- sort(unique(diabetes$ADHERENCE))
distinct_adherence_values

# split the dataset into training and testing sets
set.seed(1234)

sample_index <- sample(nrow(diabetes),nrow(diabetes)*0.80)

train <- diabetes[sample_index, ]
test  <- diabetes[-sample_index, ]

# plotting  current age, adherence, and gender as these columns will come over
# as is for analysis
age_histogram <- hist(train$`CURRENT AGE`,
     main = "Histogram of Age",
     xlab = "Age",
     col = "steelblue",
     border = "white")


adherence_barplot <- barplot(table(train$ADHERENCE),
        main = "Barplot of Adherence",
        ylab = "Count",
        col = "steelblue")


gender_barplot <- barplot(table(train$GENDER),
        main = "Barplot of Gender",
        ylab = "Count",
        col = "steelblue")

age_histogram
adherence_barplot
gender_barplot

# percentage of men and women in dataset
sum_women <- sum(train$GENDER == "F")
sum_men <- sum(train$GENDER == "M")
total = sum_women + sum_men
perc_women <- round(sum_women / total, digits = 4)*100
percent_women <- paste("Percent of women is", perc_women)
perc_men <- round(sum_men / total, digits = 4)*100
percent_men <- paste("Percent of men is", perc_men)

print(percent_women)
print(percent_men)


# how many prescriptions each patient has
prescriptions_per_patient <- train %>%
  group_by(`PZTIQNT NZXQ`) %>%
  summarize(
    num_prescriptions = n_distinct(`CODE DESCRIPTION`),
    .groups = "drop"
  )
prescriptions_per_patient



# count the number of patients for each number of prescriptions
prescription_distribution <- prescriptions_per_patient %>%
  count(num_prescriptions)
prescription_distribution


# plot how many prescriptions each patient has
num_of_prescriptions_plot <- ggplot(prescription_distribution, aes(x = num_prescriptions, y = n)) +
  geom_col(fill = "steelblue") +
  labs(
    title = "Number of Prescriptions per Patient",
    x = "Distinct Prescriptions",
    y = "Number of Patients"
  ) +
  theme(  panel.background = element_blank())
num_of_prescriptions_plot

# ==============================================================================
# 3. THE INSIGHT -> CONSTRUCTING DYNAMIC REFILLS ----
# ==============================================================================
# engineering custom time-series adherence metrics by developing algorithmic
# logic to calculate dynamic prescription refill intervals and statistical
# central tendencies (mean and median) in the absence of explicit dosage data

# function to find the number of days between prescription pickups if patient
# has at least 2 service dates (ie at least 2 pickups). Done for each 
# prescription separately
create_refill_gaps <- function(df) {
  
  df %>%
    group_by(`PZTIQNT NZXQ`, `CODE DESCRIPTION`) %>%
    arrange(`SERVICE DATE`) %>%
    filter(n() >= 2) %>%
    mutate(
      next_fill_date = lead(`SERVICE DATE`),
      days_between_fills = as.numeric(next_fill_date - `SERVICE DATE`)
    ) %>%
    ungroup()
}


# function to calculate the mean, median, and difference between the two. Count
#how many visits and how many gaps there are
create_refill_summary <- function(df) {
  
  df %>%
    arrange(`PZTIQNT NZXQ`, `SERVICE DATE`) %>% 
    group_by(`PZTIQNT NZXQ`) %>% 
    mutate(
      days_between_fills = `SERVICE DATE` - lag(`SERVICE DATE`)
    ) %>%
    summarize(
      mean_gap   = mean(days_between_fills, na.rm = TRUE),
      median_gap = median(days_between_fills, na.rm = TRUE),
      diff_gap   = mean_gap - median_gap,
      visits     = n(),
      gaps_count = sum(!is.na(days_between_fills))
    ) %>%
    filter(gaps_count >= 1) %>%
    arrange(desc(diff_gap))
}


# function to create age and gender
create_age_gender <- function(refill_gaps) {
  
  refill_gaps %>%
    group_by(`PZTIQNT NZXQ`) %>%
    summarize(
      age    = first(`CURRENT AGE`),
      gender = first(GENDER),
      adherence = first(ADHERENCE)
    )
}



# function to convert the difference between average and median to a numeric
# value and put the column next to the diff_gap column
convert_diff_gap <- function(df) {
  
  df$diff_gap_num <- as.numeric(df$diff_gap, units = "days")
  cols <- names(df)
  pos <- match("diff_gap", cols)
  
  new_order <- c(
    cols[1:pos],
    "diff_gap_num",
    cols[(pos + 1):length(cols)][cols[(pos + 1):length(cols)] != "diff_gap_num"]
  )
  df <- df[, new_order, drop = FALSE]
  
  df
}



# function to add age and gender to new dataset
add_age_gender <- function(df, age_gender) {
  
  df <- df %>%
    left_join(age_gender, by = "PZTIQNT NZXQ")
  cols <- names(df)
  
  new_order <- c(
    "PZTIQNT NZXQ",
    "age",
    "gender",
    setdiff(cols, c("PZTIQNT NZXQ", "age", "gender"))
  )
  df <- df[, new_order, drop = FALSE]
  
  df
}



# function to add prescription counts
add_prescription_counts <- function(current_df, old_df) {
  
  prescription_counts <- old_df %>%
    group_by(`PZTIQNT NZXQ`) %>%
    summarize(
      num_prescriptions = n_distinct(`CODE DESCRIPTION`)
    )
  current_df <- current_df %>%
    left_join(prescription_counts, by = "PZTIQNT NZXQ")
  
  current_df
}


# function to add adherent binary
add_adherent_binary <- function(df) {
  
  df <- df %>%
    mutate(
      adherent_binary = as.integer(diff_gap_num < 5)
    )
  
  df
}


# function to rename patient column
rename_patient_column <- function(df) {
  
  names(df)[names(df) == "PZTIQNT NZXQ"] <- "patient"
  
  df
}


# find the number of days between pickups
refill_gaps <- create_refill_gaps(train)



# count the number of days between refills and use to group patients. Order by 
# patient
gap_counts <- refill_gaps %>%
  filter(!is.na(days_between_fills)) %>%
  group_by(days_between_fills) %>%
  summarize(num_patients = n()) %>%
  filter(num_patients > 1) %>%
  arrange(desc(num_patients)) 

gap_counts



# count the number of rows for each units value
units_counts <- train %>%
  group_by(UNITS) %>%
  summarize(num_rows = n()) %>%
  arrange(desc(num_rows))

units_counts



# bin the refill gaps data
refill_gaps$gap_group <- cut(
  refill_gaps$days_between_fills,
  breaks = c(-Inf, 25, 40, 55, 70, 96, 130, Inf),
  labels = c("0-25", "26-40", "41-55", "56-70", "71-96", "97-130", "130+"),
  right = TRUE
)



# count the number of patients in each refill gaps bin
gap_group_counts <- refill_gaps %>%
  group_by(gap_group) %>%
  summarize(num_patients = n())
gap_group_counts



# calculate the mean, median, and difference between the two. Count how many 
# visits and how many gaps there are
refill_summary <- create_refill_summary(refill_gaps)



# create numeric column for number of days
refill_summary <- convert_diff_gap(refill_summary)



# bin the difference between average and median to see the breakdown of how
# many days between them
temp_bins <- cut(
  refill_summary$diff_gap_num,
  breaks = c(-Inf, 5, 7, 9, 11, 20, 30, 40, Inf),
  labels = c("<5", "5-7", "7-9", "9-11", "11-20", "20-30", "30-40", ">40"),
  right = TRUE
)
table(temp_bins)



# plot the bins
bin_counts <- table(temp_bins)

bin_counts_barplot <- barplot(
  bin_counts,
  main = "Histogram of the difference between average and median",
  xlab = "diff between average and median",
  ylab = "Count",
  col = "steelblue"
)
bin_counts_barplot

# make table with age and gender from secondary dataset
age_gender_table <- create_age_gender(refill_gaps)



# add age and gender columns to dataset
refill_summary <- add_age_gender(refill_summary, age_gender_table)



# count num of prescriptions for each patient and add to dataset
refill_summary <- add_prescription_counts(refill_summary, refill_gaps)



# create binary flag to mark all rows with the diff < 5 as adherent
refill_summary <- add_adherent_binary(refill_summary)



# rename columns for consistency
refill_summary <- rename_patient_column(refill_summary)


# recheck dimensions
head(refill_summary)
dim(refill_summary)


# set up the entire dataset
refill_gaps_full <- create_refill_gaps(diabetes)
refill_summary_full <- create_refill_summary(refill_gaps_full)
age_gender_full <- create_age_gender(refill_gaps_full)
refill_summary_full <- convert_diff_gap(refill_summary_full)
refill_summary_full <- add_age_gender(refill_summary_full, age_gender_full)
refill_summary_full <- add_prescription_counts(refill_summary_full, diabetes)
refill_summary_full <- add_adherent_binary(refill_summary_full)
refill_summary_full <- rename_patient_column(refill_summary_full)
refill_summary_full$mean_gap   <- as.numeric(refill_summary_full$mean_gap)
refill_summary_full$median_gap <- as.numeric(refill_summary_full$median_gap)
refill_summary_full$diff_gap   <- as.numeric(refill_summary_full$diff_gap)
refill_summary_full$gender <- as.factor(refill_summary_full$gender)

# ==============================================================================
# 4. POST-TRANSFORMATION EDA & SPLITTING ----
# ==============================================================================
# check new dataset and split into training and testing datasets

# audit of data in each column
head(refill_summary_full)

# audit of dataset dimensions
dim(refill_summary_full)


# split updated dataset into training and testing data
set.seed(1234)

summary_sample_index <- sample(nrow(refill_summary_full),
                               nrow(refill_summary_full)*0.80)

patient_train <- refill_summary_full[summary_sample_index, ]
patient_test  <- refill_summary_full[-summary_sample_index, ]

# ==============================================================================
# 5. EXPORT FINAL WORKING DATA ----
# ==============================================================================
# save training data
saveRDS(patient_train, "data/train_data.rds")

# save testing data
saveRDS(patient_test, "data/test_data.rds")
