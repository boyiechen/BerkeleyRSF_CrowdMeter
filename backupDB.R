# The script copy all the rows from DB and export the csv file to another repo

library(readr)
library(DBI)
library(RSQLite)

# Load DB
conn <- dbConnect(SQLite(), "./database")
df <- dbReadTable(conn, "db")
# Write CSV
write_csv(df, "/home/rpi/repo/database/UCB_RSF.csv")
