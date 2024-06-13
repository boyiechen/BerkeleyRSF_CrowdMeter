# Load necessary libraries
library(dplyr)
library(ggplot2)
library(GGally)
library(lubridate)

source("./config.R")

# Assuming df is your cleaned data frame
# If not loaded, load the data frame from the database
conn <- dbConnect(drv = RSQLite::SQLite(), dbname = "database")
df <- dbReadTable(conn, "cleanedData")

# recover the datetime object
df <- df %>% 
  mutate(by5 = lubridate::ymd_hms(by5),
         by15 = lubridate::ymd_hms(by15))

# Select relevant columns for correlation analysis
correlation_data <- df %>%
  select(count, temp, temp_feel, temp_min, temp_max, pressure, humidity)

# Plot correlation matrix
correlation_plot <- ggpairs(correlation_data, 
                            upper = list(continuous = wrap("cor", size = 4, color = "black")),
                            lower = list(continuous = wrap("points", size = 0.5, alpha = 0.3)),
                            diag = list(continuous = wrap("densityDiag", fill = "lightblue"))) +
  labs(title = "Correlation Plot of Weather Variables and Gym Attendance")

# Save the plot as an image
ggsave("./plot/correlation_plot.png", plot = correlation_plot, width = 12, height = 10)

# Notify user about the saved file
print("The correlation plot has been saved as 'correlation_plot.png' in the current working directory.")
