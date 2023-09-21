#' @title Instant Crowd Meter Predictor - Modeling
#' @author Boyie Chen
#' @description 
#' The following script model the people count provided by scrawling the crowd meter
#' And by utilizing the model parameter, I provide the real time prediction

# clean up env
rm(list = ls())

# Dependencies
library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)
library(tidymodels)
library(poissonreg) # apply glm engine for poisson reg
library(RSQLite)

# Set up env
Sys.setenv(TZ='US/Pacific')
# as.POSIXct(tz = "US/Pacific")
#setwd("/Users/Andy 1/google_drive/Coding_Projects/RSF/repo")
setwd("/home/boyie/repo/BerkeleyRSF_CrowdMeter/")
#setwd("C:/Users/boyie/Programming/BerkeleyRSF_CrowdMeter")
source("rshinyapp/functions.R")

# Build up DB connection
conn <- dbConnect(drv = RSQLite::SQLite(), dbname = "database")
df <- dbReadTable(conn, "cleanedData")

# recover the datetime object
df <- df %>% 
  # mutate(by5 = as.POSIXct(by5, origin = "1970-01-01", tz = "US/Pacific"),
  #        by15 = as.POSIXct(by15, origin = "1970-01-01", tz = "US/Pacific")) %>% 
  mutate(by5 = lubridate::ymd_hms(by5),
         by15 = lubridate::ymd_hms(by15))

#####----- Modeling -----#####
# timer
t0 <- Sys.time()
# using tidy model
df_model <- df %>% 
  mutate(weekday = as.factor(weekday),
         hour = as.factor(hour),
         minute = as.factor(minute)) %>% 
  select(by5, count, 
         temp, temp_feel, temp_min, temp_max, 
         pressure, humidity, 
         weekday, hour, minute)
# split training set and testing set
idx <- nrow(df) - 4032 # test set is two-week long
df_train <- df_model[1:idx,]
df_test <- df_model[-(1:idx),]

# pre-process: create lag variables as predicting model characteristics
modelRecipe <- recipe(count ~., data = df_train) %>% 
  step_rm(by5) %>%
  step_lag(count, lag = 1:288) %>% 
  step_lag(temp, temp_feel, temp_min, temp_max,
           pressure, humidity,
           lag = 1:12) %>%
  step_rm(temp, temp_feel, temp_min, temp_max,
          pressure, humidity)

# after pre-processing (create predictors)
df_train_processed <- modelRecipe %>%
  prep(df_train) %>%
  bake(df_train)
df_test_processed <- modelRecipe %>%
  prep(df_test) %>%
  bake(df_test)

# parsnip
linear_reg_lm_spec <- linear_reg() %>%
  set_engine('lm')

# Fit the models
lmFit <- fit(linear_reg_lm_spec, count ~ ., data = df_train_processed)

# Show estimation
# lmFit %>% tidy() %>% drop_na() %>% View
# lmFit %>% tidy() %>% drop_na() %>% filter(p.value < 0.05) %>% View

# evaluate performance
## Linear Regression
df_eval_lm <- df_test_processed %>%
  dplyr::select(count) %>%
  bind_cols(predict(lmFit, df_test_processed)) %>% 
  bind_cols(df_test %>% select(by5)) %>% 
  filter(row_number() >= (4032 - 288) )
plot_lm <- df_eval_lm %>% 
  ggplot()+
  geom_line(aes(by5, count, col = "real"))+
  geom_line(aes(by5, .pred, col = "pred"))+
  ylim(c(-10, 200))
err_lm <- df_eval_lm %>% mutate(err = count - .pred) %>% select(err) %>% unlist
loss_lm <- sqrt(sum(err_lm^2))
cat(">>> The squared loss of linear model is ", loss_lm, "\n")


##### Generate Real-time Prediction #####
# adding additional row as the predicted value place holder
df_pred <- df_test %>% 
  bind_rows(tail(df_test, 1) %>% 
              mutate(by5 = by5 + 300,
                     count = NA,
                     temp = NA, temp_feel = NA, temp_min = NA, temp_max = NA,
                     pressure = NA, humidity = NA) %>% 
              mutate(weekday = as.factor(lubridate::wday(by5)),
                     hour = as.factor(lubridate::hour(by5)),
                     minute = as.factor(lubridate::minute(by5)))
            )
# paste the predicted value
df_pred_processed <- modelRecipe %>% prep(df_pred) %>% bake(df_pred)

#' @note
#' `df_pred` is a df contains real value except for the last row with `count=NA`
#' `df_outcome` is a df contains only predicted values from the model estimation
df_outcome <- df_pred_processed %>%
  dplyr::select(count) %>%
  bind_cols(predict(lmFit, df_pred_processed)) %>% 
  bind_cols(df_pred %>% select(by5)) %>% 
  filter(row_number() >= (4032 - 288*1.2) )

# a new `df_pred`
df_pred <- df_pred %>% coalesce_join(
  (df_outcome %>% tail(1) %>% select(by5, count = .pred)),
  by = c("by5")
)


# repeat prediction
for(i in 1:288){ # 24 hrs has 288 5-min intervals
  df_pred <- df_pred %>% 
    bind_rows(tail(df_pred, 1) %>% 
                mutate(by5 = by5 + 300,
                       count = NA,
                       temp = NA, temp_feel = NA, temp_min = NA, temp_max = NA,
                       pressure = NA, humidity = NA) %>% 
                mutate(weekday = as.factor(lubridate::wday(by5)),
                       hour = as.factor(lubridate::hour(by5)),
                       minute = as.factor(lubridate::minute(by5)))
    )
  df_pred_processed <- modelRecipe %>% prep(df_pred) %>% bake(df_pred)
  df_pred_processed <- df_pred_processed %>%
    fill(!!colnames(df_pred_processed),
         .direction = "down") 

  df_outcome <- df_pred_processed %>%
    dplyr::select(count) %>%
    bind_cols(predict(lmFit, df_pred_processed)) %>% 
    bind_cols(df_pred %>% select(by5)) %>% 
    filter(row_number() >= (4032 - 288*1.2) )
  
  df_pred <- df_pred %>% coalesce_join(
    (df_outcome %>% tail(1) %>% select(by5, count = .pred)),
    by = c("by5")
  )
}

# adding s.e. for prediction interval
df_outcome_plot <- df_outcome %>%
  mutate(isPred = ifelse(count == .pred, 1, 0)) %>% 
  mutate(Peak = max(isPred * .pred),
         isPeak = ifelse(.pred == Peak, 1, 0),
         ) %>% 
  mutate(upper = ifelse(isPred == 1, 
                        .pred + 1.96*sd(err_lm),
                        NA),
         lower = ifelse(isPred == 1, 
                        .pred - 1.96*sd(err_lm),
                        NA)
         )
t1 <- Sys.time()
print(format(t1 - t0))

# Write cleaned data
df_outcome_plot <- df_outcome_plot %>% 
  mutate(by5 = as.character(by5))
dbWriteTable(conn, name = "reportData", value = df_outcome_plot, overwrite = TRUE)

# Save csv
write_csv(df_outcome_plot, file = "rshinyapp/reportData.csv")
