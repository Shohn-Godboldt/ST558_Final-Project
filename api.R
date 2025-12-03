# api.R — Diabetes Classification Tree API ---------------------------------

library(tidyverse)
library(janitor)
library(tidymodels)
library(yardstick)
library(plumber)

set.seed(123)

# 1. Read and prepare the full data -----------------------------------------

diab <- read_csv("diabetes_binary_health_indicators_BRFSS2015.csv") |>
  clean_names() |>
  mutate(
    diabetes_binary = factor(diabetes_binary, levels = c(0, 1),
                             labels = c("NoDiabetes", "Diabetes")),
    high_bp        = factor(high_bp),
    high_chol      = factor(high_chol),
    chol_check     = factor(chol_check),
    smoker         = factor(smoker),
    stroke         = factor(stroke),
    heart_diseaseor_attack = factor(heart_diseaseor_attack),
    phys_activity  = factor(phys_activity),
    gen_hlth       = factor(gen_hlth, ordered = TRUE)
  )

tidymodels_prefer()

# Use the SAME predictors as in Modeling.qmd
full_recipe <- recipe(diabetes_binary ~ bmi + high_bp + high_chol +
                        phys_activity + gen_hlth,
                      data = diab) |>
  step_normalize(all_numeric_predictors())

# 2. Final classification tree spec -----------------------------------------
# ⬇️ IMPORTANT: plug in the values from `tree_best` in your Modeling.qmd
# e.g. cost_complexity = 0.01, tree_depth = 5, min_n = 20 (these are EXAMPLES)
tree_spec_final <- decision_tree(
  cost_complexity = 0.001,
  tree_depth      = 8,
  min_n           = 10
) |>
  set_mode("classification") |>
  set_engine("rpart")

tree_wf_final <- workflow() |>
  add_recipe(full_recipe) |>
  add_model(tree_spec_final)

# Fit final model on the *entire* dataset (per rubric)
tree_fit_full <- fit(tree_wf_final, data = diab)

# 3. Defaults for API parameters --------------------------------------------

default_bmi <- mean(diab$bmi, na.rm = TRUE)

default_high_bp <- as.integer(names(which.max(table(diab$high_bp))))
default_high_chol <- as.integer(names(which.max(table(diab$high_chol))))
default_phys_activity <- as.integer(names(which.max(table(diab$phys_activity))))
default_gen_hlth <- as.integer(names(which.max(table(diab$gen_hlth))))

# helper for confusion matrix data
get_confusion_df <- function() {
  preds <- predict(tree_fit_full, diab, type = "class") |>
    bind_cols(predict(tree_fit_full, diab, type = "prob")) |>
    bind_cols(diab |> select(diabetes_binary))
  
  preds
}

# 4. API endpoints ----------------------------------------------------------

#* @apiTitle Diabetes Health Indicators – Classification Tree API

#* Predict probability of diabetes
#*
#* This endpoint takes the predictors used in the final model and returns
#* the predicted class and probability of Diabetes.
#*
#* @param bmi:numeric Body mass index
#* @param high_bp:int High blood pressure indicator (0 = No, 1 = Yes)
#* @param high_chol:int High cholesterol indicator (0 = No, 1 = Yes)
#* @param phys_activity:int Physical activity (0 = No, 1 = Yes)
#* @param gen_hlth:int Self-rated general health (1 = Excellent ... 5 = Poor)
#* @get /pred
function(bmi = default_bmi,
         high_bp = default_high_bp,
         high_chol = default_high_chol,
         phys_activity = default_phys_activity,
         gen_hlth = default_gen_hlth) {
  
  new_df <- tibble(
    bmi           = as.numeric(bmi),
    high_bp       = factor(as.integer(high_bp),  levels = levels(diab$high_bp)),
    high_chol     = factor(as.integer(high_chol), levels = levels(diab$high_chol)),
    phys_activity = factor(as.integer(phys_activity),
                           levels = levels(diab$phys_activity)),
    gen_hlth      = factor(as.integer(gen_hlth),
                           ordered = TRUE,
                           levels = levels(diab$gen_hlth))
  )
  
  probs <- predict(tree_fit_full, new_df, type = "prob")
  class <- predict(tree_fit_full, new_df, type = "class")
  
  list(
    input       = new_df,
    prediction  = class$.pred_class,
    prob_Diabetes = probs$.pred_Diabetes
  )
}

# Example API calls (for instructor to copy in browser):
# http://localhost:8000/pred?bmi=30&high_bp=1&high_chol=1&phys_activity=0&gen_hlth=4
# http://localhost:8000/pred?bmi=24&high_bp=0&high_chol=0&phys_activity=1&gen_hlth=2
# http://localhost:8000/pred?bmi=35&high_bp=1&high_chol=1&phys_activity=0&gen_hlth=5


#* Basic info about the API
#* @get /info
function() {
  list(
    name = "Shohn Godboldt",
    github_pages_url = "https://github.com/Shohn-Godboldt/ST558_Final-Project/"
  )
}

#* Confusion matrix plot for the full-data model fit
#* @serializer png
#* @get /confusion
function() {
  
  preds <- get_confusion_df()
  
  cm <- conf_mat(
    preds,
    truth   = diabetes_binary,
    estimate = .pred_class
  )
  
  mat <- as.matrix(cm$table)
  
  # Simple base R heatmap of confusion matrix
  par(mar = c(5, 5, 4, 2))
  image(
    1:nrow(mat), 1:ncol(mat), t(mat[nrow(mat):1, ]),
    xlab = "Predicted", ylab = "Actual",
    axes = FALSE
  )
  axis(1, at = 1:ncol(mat), labels = colnames(mat))
  axis(2, at = 1:nrow(mat), labels = rev(rownames(mat)))
  text(
    rep(1:ncol(mat), each = nrow(mat)),
    rep(1:nrow(mat), times = ncol(mat)),
    labels = as.vector(t(mat[nrow(mat):1, ]))
  )
}
