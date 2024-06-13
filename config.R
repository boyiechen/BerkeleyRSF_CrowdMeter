rm(list = ls())

library(dotenv)
load_dot_env()

PROJECT_PATH <- Sys.getenv("PROJECT_PATH")

# set up working directory for R
setwd(PROJECT_PATH)

# Set up env
Sys.setenv(TZ='US/Pacific')

