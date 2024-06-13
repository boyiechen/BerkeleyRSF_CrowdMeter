# Load necessary libraries
library(dplyr)
library(ggplot2)
library(lubridate)

source("./config.R")

# Assuming df is your cleaned data frame
# If not loaded, load the data frame from the database
conn <- dbConnect(drv = RSQLite::SQLite(), dbname = "database")
df <- dbReadTable(conn, "cleanedData")

# recover the datetime object
df <- df %>% 
  # mutate(by5 = as.POSIXct(by5, origin = "1970-01-01", tz = "US/Pacific"),
  #        by15 = as.POSIXct(by15, origin = "1970-01-01", tz = "US/Pacific")) %>% 
  mutate(by5 = lubridate::ymd_hms(by5),
         by15 = lubridate::ymd_hms(by15))

# Create additional time variables
df <- df %>%
  mutate(hour = hour(by5),
         weekday = weekdays(by5))

# Calculate the average count for each hour of each weekday
heatmap_data <- df %>%
  group_by(weekday, hour) %>%
  summarise(average_count = mean(count, na.rm = TRUE)) %>%
  ungroup()

# Order the weekdays correctly
heatmap_data$weekday <- factor(heatmap_data$weekday, 
                               levels = c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))

# Plot the heatmap
ggplot(heatmap_data, aes(x = hour, y = weekday, fill = average_count)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "white", high = "red") +
  labs(title = "Heatmap of Gym Attendance",
       x = "Hour of the Day",
       y = "Day of the Week",
       fill = "Average Count") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

