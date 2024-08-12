#' @title Instant Crowd Meter Predictor - Data Preparation for Modeling
#' @author Boyie Chen
#' @description 
#' The following script model the people count provided by scrawling the crowd meter
#' And by utilizing the model parameter, I provide the real time prediction

# Set up env
source("./config.R")

# Dependencies
library(readr)
library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(lubridate)
library(RSQLite)

# Build up DB connection
conn <- dbConnect(drv = RSQLite::SQLite(), dbname = "database")
rawdata <- dbReadTable(conn, "db")

# clean data
df <- rawdata %>% 
  # parse datetime object
  mutate(Timestamp = lubridate::ymd_hm(Timestamp)) %>% 
  # Create weekday
  # 1: Sun., 2: Mon., ..., 6: Sat.
  mutate(weekday = lubridate::wday(Timestamp)) %>% 
  # Arrange by Timestamp
  arrange(Timestamp) %>% 
  # Create 15-min intervals
  mutate(by15 = cut(Timestamp, "15 min")) %>% 
  # Group by 5-min intervals
  group_by(by5 = cut(Timestamp, "5 min")) %>% 
  # Summarise data by 5-min intervals
  summarise(
    count = mean(current_count),
    ratio = mean(capacity_ratio),
    temp = mean(temp),
    temp_feel = mean(temp_feel),
    temp_min = mean(temp_min),
    temp_max = mean(temp_max),
    pressure = mean(pressure),
    humidity = mean(humidity),
    weekday = first(weekday),
    by15 = first(by15)
  ) %>% 
  # Convert `by5` and `by15` to POSIXct date-time format
  mutate(
    by5 = as.POSIXct(by5, format="%Y-%m-%d %H:%M:%S"),
    by15 = as.POSIXct(by15, format="%Y-%m-%d %H:%M:%S")
  ) %>% 
  # Apply additional transformations
  mutate(count = ifelse(count <= 10, 0, count))


# Fill missing 15-minute time intervals
# Generate a complete sequence of 15-minute intervals within the range of your data
complete_intervals <- seq(min(df$by5, na.rm = TRUE), max(df$by5, na.rm = TRUE), by = "5 min")

# Convert to data frame
complete_intervals_df <- data.frame(by5 = complete_intervals)

# Merge with the original dataframe to identify missing intervals
df_filled <- complete_intervals_df %>%
  left_join(df, by = "by5")

# fill groun identifiers
df_filled <- df_filled %>%
  # weekday
  mutate(weekday = lubridate::wday(by5)) %>% 
  # every 5 minute time interval
  mutate(hour = hour(by5),
         minute15 = minute(by5)) %>% 
  # every 15 minute time interval
  mutate(by15 = cut(by5, "15 min"),
         by15 = lubridate::ymd_hms(by15),
         minute15 = lubridate::minute(by15)) 

# Identify missing intervals and fill with past mean values
df_filled <- df_filled %>%
  # to fill up average + bias for the missing value within the same past weekday at the same time
  group_by(weekday, hour, minute15) %>%
  mutate(count = ifelse(is.na(count), mean(count, na.rm = TRUE) + rnorm(1, 0, sd(count, na.rm = TRUE)/20), count),
         # count should be greater than 0
         count = ifelse(count > 0, count, 0),
         ratio = count / mean(rawdata$capacity_fulll, na.rm = TRUE),
         # temperature
         temp = ifelse(is.na(temp), mean(temp, na.rm = TRUE) + rnorm(1, 0, sd(temp, na.rm = TRUE)/20), temp),
         temp_feel = ifelse(is.na(temp_feel), mean(temp_feel, na.rm = TRUE) + rnorm(1, 0, sd(temp_feel, na.rm = TRUE)/20), temp_feel),
         temp_min = ifelse(is.na(temp_min), mean(temp_min, na.rm = TRUE) + rnorm(1, 0, sd(temp_min, na.rm = TRUE)/20), temp_min),
         temp_max = ifelse(is.na(temp_max), mean(temp_max, na.rm = TRUE) + rnorm(1, 0, sd(temp_max, na.rm = TRUE)/20), temp_max),
         pressure = ifelse(is.na(pressure), mean(pressure, na.rm = TRUE) + rnorm(1, 0, sd(pressure, na.rm = TRUE)/20), pressure),
         humidity = ifelse(is.na(humidity), mean(humidity, na.rm = TRUE) + rnorm(1, 0, sd(humidity, na.rm = TRUE)/20), humidity)) %>%
  ungroup() #%>%
  # select(-minute15) 

df_filled <- df_filled %>% 
  mutate(by5 = as.character(by5), by15 = as.character(by15))

# Write cleaned data
dbWriteTable(conn, name = "cleanedData", value = df_filled, overwrite = TRUE)
write_csv(df_filled, file = "./rshinyapp/cleanedData.csv")

# dbListTables(conn)
# dbReadTable(conn, "cleanedData")

