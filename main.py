# packages
# import requests
# import pandas as pd
import time
import datetime
import os
# import sys
# import calendar
# import matplotlib.pyplot as plt
# import matplotlib.ticker as ticker
# import pyimgur

# Load credentials
# from config import headers, weather_url, CLIENT_ID, token

# Load self-defined modules
import scrapeData
from dbManager import DBManager
from analyze import Analyzer

# Set timezone
time.strftime('%X %x %Z')
os.environ['TZ'] = 'US/Pacific'
time.tzset()
time.strftime('%X %x %Z')
now = datetime.datetime.today()

# Setting working directory
# os.chdir("/home/rpi/repo/BerkeleyRSF_CrowdMeter/")
base_path = os.getcwd()
print(base_path)

# Initialize DB connection
db_manager = DBManager(database='./db.sqlite')

# Test the functionality of scrape new data, save in DB
## load old data
db_manager.showData("db", limit=10)
df = db_manager.loadData()
print(df.shape)

## scrape new data (in type of pandas df)
scraper = scrapeData.scraper()
df_tmp = scraper.getCrowdMeterDF()
print(df_tmp)

## insert new data
db_manager.insertData(df_tmp)

## load new data
db_manager.showData("db", limit=10)
df = db_manager.loadData()
print(df.shape)


# Analysis
analysis = Analyzer()

## data cleaning
df_wk2day = analysis.filterWeekDayDF()
## create plot
analysis.makeWeekDayPlot(df_wk2day, base_path)
## upload img
analysis.uploadImg(base_path, scraper)

## if it is a new hour, then send notification
if now.minute % 60 == 0:
    # Uploading plots to Imgur
    analysis.uploadImg(base_path, scraper)