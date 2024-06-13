"""
Berkeley RSF Crowd Meter
"""
import time
import datetime
import os

# Load self-defined modules
from config import *
import scrapeData
from dbManager import DBManager
from analyze import Analyzer

# Get the current time, to have a timestamp for the scraped record
now = datetime.datetime.today()

## scrape new data (in type of pandas df)
scraper = scrapeData.scraper()
df_tmp = scraper.getCrowdMeterDF()
print(df_tmp)

# Initialize SQLite DB connection
db_manager = DBManager(database='./database')

# scrape new data, and then save in DB
df = db_manager.loadData()
# insert new data
db_manager.insertData(df_tmp)

# load new data
df = db_manager.loadData()
print(df)

# Analysis
analysis = Analyzer()

## data cleaning
df_wk2day = analysis.filterWeekDayDF(df)
## create plot
analysis.makeWeekDayPlot(df_wk2day, base_path)

## if it is a new hour, then send notification
if now.minute % 60 == 0:
    # Upload plot to Imgur
    analysis.uploadImg(base_path, scraper)
