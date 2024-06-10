#' @title Instant Crowd Meter Predictor - Data Preparation for Modeling
#' @author Boyie Chen
#' @description 
#' The following script model the people count provided by scrawling the crowd meter
#' And by utilizing the model parameter, I provide the real time prediction

# clean up env
rm(list = ls())

# Dependencies
library(readr)
library(dplyr, warn.conflicts = FALSE)
library(lubridate)
library(RSQLite)

# Set up env
Sys.setenv(TZ='US/Pacific')
#setwd("/Users/Andy 1/google_drive/Coding_Projects/RSF/repo")
setwd("/home/boyie/repo/BerkeleyRSF_CrowdMeter/")
#setwd("C:/Users/boyie/Programming/BerkeleyRSF_CrowdMeter")
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
  ## making the data as 300 seconds time frequency, i.e. 5-min interval
  arrange(Timestamp) %>% 
  mutate(by15 = cut(Timestamp, "15 min")) %>%
  # make the data in 5 min freq
  group_by(by5 = cut(Timestamp, "5 min")) %>% 
  # collapse the data in 5 min interval
  summarise(count = mean(current_count),
            ratio = mean(capacity_ratio),
            temp = mean(temp),
            temp_feel = mean(temp_feel),
            temp_min = mean(temp_min),
            temp_max = mean(temp_max),
            pressure = mean(pressure),
            humidity = mean(humidity),
            weekday = head(weekday, 1),
            by15 = head(by15, 1),
            ) %>% 
  # create dummies
  mutate(by5 = as.POSIXct(by5)) %>% 
  mutate(by5 = lubridate::ymd_hms(by5)) %>% 
  mutate(hour = lubridate::hour(by5),
         minute = lubridate::minute(by5),) %>% 
  # create dummies
  mutate(by15 = as.POSIXct(by15)) %>% 
  mutate(by15 = lubridate::ymd_hms(by15)) %>% 
  mutate(minute15 = lubridate::minute(by15),) %>% 
  # if `count` less than 10, then assign 0
  mutate(count = ifelse(count<=10, 0, count))


# Write cleaned data
df <- df %>% mutate(by5 = as.character(by5), by15 = as.character(by15))
dbWriteTable(conn, name = "cleanedData", value = df, overwrite = TRUE)
# dbListTables(conn)
# dbReadTable(conn, "cleanedData")

# Save csv
write_csv(df, file = "rshinyapp/cleanedData.csv")

