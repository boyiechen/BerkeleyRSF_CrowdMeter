import pandas as pd
import sqlite3

# Load exsited file
df = pd.read_csv("./RSF_crowd_meter.csv", index_col='Timestamp')

# Create sql file
conn = sqlite3.connect("./db.sqlite")
cursor = conn.cursor()

# Convert Pandas df to sql
df.to_sql(name='db', con=conn)
conn.close()
