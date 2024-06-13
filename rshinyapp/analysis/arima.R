# Load necessary libraries
library(dplyr)
library(lubridate)
library(forecast)
library(ggplot2)

source("./config.R")

# Assuming df is your cleaned data frame
# If not loaded, load the data frame from the database
conn <- dbConnect(drv = RSQLite::SQLite(), dbname = "database")
df <- dbReadTable(conn, "cleanedData")

# Recover the datetime object
df <- df %>% 
  mutate(by5 = lubridate::ymd_hms(by5),
         by15 = lubridate::ymd_hms(by15))

# Aggregate data to hourly level (for simplicity)
hourly_data <- df %>%
  group_by(hourly = floor_date(by5, "hour")) %>%
  summarise(count = mean(count, na.rm = TRUE))

# Convert to time series object
ts_data <- ts(hourly_data$count, frequency = 24) # Assuming data is hourly

# Fit ARIMA model
# fit <- auto.arima(ts_data)
# Fit the specified ARIMA model directly
fit <- Arima(ts_data, order = c(4, 0, 2), seasonal = c(2, 1, 0))

# Forecast for the next 24 hours
forecast_length <- 24
forecasted <- forecast(fit, h = forecast_length)

# Extract forecasted values and create a data frame for plotting
forecasted_df <- data.frame(
  time = seq(from = max(hourly_data$hourly) + hours(1), 
             by = "hour", length.out = forecast_length),
  predicted_count = as.numeric(forecasted$mean)
)

# Plot the forecasted values
ggplot(forecasted_df, aes(x = time, y = predicted_count)) +
  geom_line(color = "blue") +
  labs(title = "Gym Attendance Forecast for Next 24 Hours",
       x = "Time",
       y = "Predicted Attendance") +
  theme_minimal()

# Save the plot
ggsave("./plot/attendance_forecast.png", width = 12, height = 8)

# Print forecasted values
print(forecasted)



