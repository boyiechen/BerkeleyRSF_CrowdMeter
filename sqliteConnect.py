import sqlite3

conn = sqlite3.connect("./db.sqlite")

cursor = conn.cursor()
cursor.execute("SELECT * FROM db;")

records = cursor.fetchall()
for record in records:
    print(record)

cursor.close()
conn.close()