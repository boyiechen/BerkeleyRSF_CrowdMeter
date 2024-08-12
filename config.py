import os
import time
from dotenv import load_dotenv
load_dotenv()

# Setting working directory
os.chdir(os.getenv("PROJECT_PATH"))
base_path = os.getcwd()
print(base_path)

# Line Notify key
token = os.getenv("LINE_NOTIFY_KEY")

# Imgur
CLIENT_ID = os.getenv("IMGUR_CLIENT_ID")

# Open Weather Service
OPEN_WEATHER_API_KEY = os.getenv("OPEN_WEATHER_API_KEY")
QUERY_CITY = "Berkeley,us"

weather_url = f"http://api.openweathermap.org/data/2.5/weather?q={QUERY_CITY}&appid={OPEN_WEATHER_API_KEY}&units=metric"

# Headers for the density.io API
DENSITY_BEARER = os.getenv("DENSITY_BEARER")
headers = {
    'Authorization': f'Bearer {DENSITY_BEARER}',
    'Content-Type': 'application/json',
    'User-Agent': 'YourAppName/1.0'
}


# create the plot folder if not existed
folder = os.path.join(os.getenv("PROJECT_PATH"), "plot")
print(folder)

# Check if the directory exists and create it if it doesn't
if not os.path.exists(folder):
    os.makedirs(folder)
    print(f"Directory '{folder}' created at {folder}")
else:
    print(f"Directory '{folder}' already exists")

# Macros

# Set timezone
time.strftime('%X %x %Z')
os.environ['TZ'] = 'US/Pacific'
time.tzset()
time.strftime('%X %x %Z')

