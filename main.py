# packages
import requests
import pandas as pd
import time
import datetime
import os
import sys
import calendar
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import pyimgur
from config import headers, weather_url, CLIENT_ID, token

import scrapeData
from dbManager import DBManager


if __name__ == "__main__":

    db_manager = DBManager(database='./db.sqlite')

    # load old data
    db_manager.showData("db", limit=10)

    # scrape new data (in type of pandas df)
    scraper = scrapeData.scraper()
    df_tmp = scraper.getCrowdMeterDF()
    print(df_tmp)

    # insert new data
    db_manager.insertData(df_tmp)

    # load new data
    db_manager.showData("db", limit=10)

