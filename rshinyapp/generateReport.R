#' @title Instant Crowd Meter Predictor - Prediction Report
#' @author Boyie Chen
#' @description 
#' The following script model the people count provided by scrawling the crowd meter
#' And by utilizing the model parameter, I provide the real time prediction

# clean up env
rm(list = ls())

# Dependencies
library(dplyr)
library(ggplot2)
library(lubridate)
library(RSQLite)

# Set up env
Sys.setenv(TZ='US/Pacific')
#setwd("/Users/Andy 1/google_drive/Coding_Projects/RSF/repo")
#setwd("/home/rpi/repo/BerkeleyRSF_CrowdMeter/")
setwd("C:/Users/boyie/Programming/BerkeleyRSF_CrowdMeter")

# Build up DB connection
conn <- dbConnect(drv = RSQLite::SQLite(), dbname = "database")
df <- dbReadTable(conn, "cleanedData")
df_outcome <- dbReadTable(conn, "reportData")

# recover the datetime object
df <- df %>% 
  # mutate(by5 = as.POSIXct(by5, origin = "1970-01-01", tz = "US/Pacific"),
  #        by15 = as.POSIXct(by15, origin = "1970-01-01", tz = "US/Pacific")) %>% 
  mutate(by5 = lubridate::ymd_hms(by5),
         by15 = lubridate::ymd_hms(by15))

df_outcome <- df_outcome %>% 
  # mutate(by5 = as.POSIXct(by5, origin = "1970-01-01", tz = "US/Pacific"))
  mutate(by5 = lubridate::ymd_hms(by5))

# Plots
## Trends
### time series plot for today
df %>% 
  filter(by5 >= as.Date(Sys.Date())) %>% 
  filter(weekday == lubridate::wday(Sys.time())) %>% 
  rename(time = by5) %>% 
  ggplot(aes(x = time))+
  # ppl count
  geom_line(aes(y = count, col = "count"))+
  geom_line(aes(y = temp*2, col = "temp"))+
  geom_vline(xintercept = max(df$by5), color = 'grey')+
  # geom_hline(aes(yintercept = 91, col = "limit"))+
  scale_y_continuous(
    name = "Count",
    # Add a second axis and specify its features
    sec.axis = sec_axis(~./2, name="Temperature (ºC)")
  )+
  labs(title = "Number of people in RSF, Today")

### time series plot for selected weekday
user_input_wday <- 3
df %>% 
  filter(weekday == user_input_wday) %>% 
  mutate(date_preserved = lubridate::date(max(by5))) %>% 
  group_by(hour, minute) %>%
  summarise(count = mean(count),
            count_u = quantile(count, probs = 0.95),
            count_l = quantile(count, probs = 0.05),
            temp = mean(temp),
            date_preserved = tail(date_preserved, 1),
  ) %>% 
  mutate(HM = paste0(hour, ":", minute)) %>% 
  mutate(HM = lubridate::hm(HM)) %>% 
  mutate(time = date_preserved + HM) %>% 
  ggplot()+
  # people count
  geom_line(aes(time, count, col = "avg. count"))+
  geom_line(aes(time, temp*2, col = "avg. temperature"))+
  scale_size_area(limits = c(0, 1000), max_size = 10, guide = NULL)+
  scale_y_continuous(
    name = "Count",
    # Add a second axis and specify its features
    sec.axis = sec_axis(~./2, name="Temperature (ºC)")
  )+
  labs(title = paste0("Number of people in RSF"))


## Predictions
peak_time <- (df_outcome %>% filter(isPeak == 1) %>% select(by5))$by5
peak_count <- df_outcome$Peak[1]
string1 <- paste0("The model forecasts that the peak time will be:", as.character(peak_time))
string2 <- paste0("The model forecasts that the peak will be:", round(peak_count))
cat(string1, "\n", string2)

df_outcome %>% 
  ggplot()+
  # adding prediction as shaded area
  geom_rect(data = subset(df_outcome, isPeak == 1),
            aes(ymin = -Inf, ymax = Inf, xmin = by5, xmax = by5),
            alpha = 0.2, color = 'grey')+
  geom_line(aes(by5, count, col = "real"))+
  geom_line(aes(by5, .pred, col = "pred"))+
  geom_line(aes(by5, upper),
            color = "grey59", linetype = "dashed")+
  geom_line(aes(by5, lower),
            color = "grey59", linetype = "dashed")+
  ylim(c(-20, 160))
