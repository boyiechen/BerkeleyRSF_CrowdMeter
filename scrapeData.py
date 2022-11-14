# packages
import requests
import pandas as pd
import time
import datetime
import os
import sys
from config import headers, weather_url 

class scraper(object):

    def __init__(self, headers = headers, weather_url = weather_url):
        self.url = "https://api.density.io/v2/displays/dsp_956223069054042646"
        self.headers = headers
        self.weather_url = weather_url
        self.count_dict = {}
        
    def getCrowdMeterDF(self):
        self.fetchCrowdMeterNow()
        self.fetchWeatherNow()

        # build dataframe
        tmp = pd.DataFrame.from_dict([self.count_dict])
        tmp = tmp.set_index("Timestamp")
        # tmp.to_csv(f"{base_path}/RSF_tmp.csv")
        if tmp.shape[0] == 0:
            print("NO DATA, EXIT PROGRAM")
            sys.exit()

        return tmp

    def fetchCrowdMeterNow(self):
        # UC Berkeley RSF data
        ## directly scrape XHR file
        res = requests.get(self.url, headers = self.headers)
        XHR_dict = res.json()
        current_count = XHR_dict["dedicated_space"]["current_count"]
        capacity_full = XHR_dict["dedicated_space"]["capacity"]
        
        # build dictionary
        self.count_dict["current_count"] = current_count
        self.count_dict["capacity_fulll"] = capacity_full
        self.count_dict["capacity_ratio"] = round(current_count / capacity_full, 4)
        self.count_dict["Timestamp"] = datetime.datetime.today().strftime("%Y-%m-%d %H:%M")

    def fetchWeatherNow(self):
        # attach weather info
        res = requests.get(self.weather_url)
        weather_res = res.json()
        self.count_dict["temp"] = weather_res["main"]["temp"]
        self.count_dict["temp_feel"] = weather_res["main"]["feels_like"]
        self.count_dict["temp_min"] = weather_res["main"]["temp_min"]
        self.count_dict["temp_max"] = weather_res["main"]["temp_max"]
        self.count_dict["pressure"] = weather_res["main"]["pressure"]
        self.count_dict["humidity"] = weather_res["main"]["humidity"]
