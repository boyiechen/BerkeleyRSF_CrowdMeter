import time
import requests
import datetime
import calendar
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import pyimgur

from dbManager import DBManager
from config import CLIENT_ID, token

class Analyzer:
    def __init__(self):
        # Find the 15-min intervals
        self.time_interval_dict = {x : f"{x*15//60}:{x*15%60}" for x in range(0,97)}
        self.WeekDayToday = datetime.datetime.today().weekday()
        self.WeekDayDict = {
            0 : "Monday",
            1 : "Tuesday",
            2 : "Wednesday",
            3 : "Thursday",
            4 : "Friday",
            5 : "Saturday",
            6 : "Sunday",
        }

    @staticmethod
    def findTimeInterval(date): 
        t_hour = datetime.datetime.strptime(date, '%Y-%m-%d %H:%M').hour
        t_minute = datetime.datetime.strptime(date, '%Y-%m-%d %H:%M').minute
        t_HM = t_hour*60+t_minute
        return (t_HM//15)


    # Get week day from a given date
    @staticmethod
    def findDay(date): 
        born = datetime.datetime.strptime(date, '%Y-%m-%d %H:%M').weekday() 
        return (calendar.day_name[born])




    def filterWeekDayDF(self, df = None):
        if df is None: # then load the default dataframe from SQLite database
            df = DBManager().loadData(table_name = 'db')
        df = df.sort_values(by = "Timestamp", ascending = False)
        
        # Modeling and Data Manipulation
        # equivalent to column 1: date
        df["TimeInterval"] = df.iloc[0:len(df),0].map(lambda x:self.findTimeInterval(x))
        
        # Get week day from a given date
        date_text = df.iloc[0:len(df),0][0]
        df["WeekDay"] = df.iloc[0:len(df),0].map(lambda x:self.findDay(x))

        # Filter the samples that match today's weekday
        df_wk2day = df[df["WeekDay"] == self.WeekDayDict[self.WeekDayToday]]
        # df_wk2day = df_wk2day.groupby("TimeInterval").mean()
        # the above line is about to deprecated, and the following line is the new one
        df_wk2day = df_wk2day.groupby("TimeInterval").agg({'current_count':'mean', 'capacity_fulll':'mean', 'capacity_ratio':'mean', 'temp':'mean', 'temp_feel':'mean', 'humidity':'mean', 'pressure':'mean'}).reset_index()

        return df_wk2day

    def makeWeekDayPlot(self, df_wk2day, base_path):

        # Preparing for plot
        x = [self.time_interval_dict[key] for key in list(df_wk2day.index)]
        y = df_wk2day['current_count']

        tick_spacing = 8
        fig, ax = plt.subplots(1,1)
        ax.plot(x,y)
        ax.xaxis.set_major_locator(ticker.MultipleLocator(tick_spacing))
        plt.savefig(f"{base_path}/plot/plot.jpg")

    # Send line notification
    @staticmethod
    def sendNotification(text = "", img_url = "", token = ""):
        headers = {
            "Authorization": "Bearer " + token,
            "Content-Type": "application/x-www-form-urlencoded"
        }
        params = {"message": text,
                "imageFullsize" : img_url,
                "imageThumbnail": img_url}
        r = requests.post("https://notify-api.line.me/api/notify",
                        headers=headers, params=params)
        print(r.status_code)  #200
        print("發送Line通知囉！")
        time.sleep(1)

    def uploadImg(self, base_path, scraper):
        # Uploading plots to Imgur
        PATH = f"{base_path}/plot/plot.jpg"
        title = "Uploaded with PyImgur"
        im = pyimgur.Imgur(CLIENT_ID)
        uploaded_image = im.upload_image(PATH, title=title)
        print(uploaded_image.title)
        print(uploaded_image.link)
        print(uploaded_image.type)

        key = 'current_count'
        self.sendNotification(text = f"\nUC Berkeley RSF\n資料抓取時刻：\n{scraper.count_dict['Timestamp']}\n{key} : {scraper.count_dict[key]}人\n人數上限：{scraper.count_dict['capacity_fulll']}人\n容留比例：{scraper.count_dict['capacity_ratio']}\n現在氣溫：攝氏{scraper.count_dict['temp']}\n體感溫度：攝氏{scraper.count_dict['temp_feel']}\n現在濕度：{scraper.count_dict['humidity']}%\n現在氣壓：{scraper.count_dict['pressure']}帕", 
                            img_url = uploaded_image.link,
                            token = token)
