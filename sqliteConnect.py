import sqlite3

conn = sqlite3.connect("./db.sqlite")

cursor = conn.cursor()
cursor.execute("SELECT * FROM db;")

records = cursor.fetchall()
print(records)

cursor.close()
conn.close()