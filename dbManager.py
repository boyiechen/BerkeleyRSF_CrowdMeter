# import mysql.connector 
import sqlite3
import pandas as pd

class DBManager:
    def __init__(self, database = "./database"):
        self.conn = sqlite3.connect(database)
        self.cursor = self.conn.cursor()

    def insertData(self, df_scraped):
        """
        Tha name of the table to store all scraped data is 'db'
        """
        # sql = "INSERT INTO db (StudentID, Name, City) VALUES (%s, %s, %s)"
        # self.cursor.execute(sql, student_info)
        df_scraped.to_sql(name = 'db', con = self.conn, if_exists = 'append')
    
    def showData(self, table_name = 'db', limit = 10):
        self.cursor.execute(f"SELECT * FROM `{table_name}` LIMIT {limit}")

        values = self.cursor.fetchall()
        for student in values:
            print(student)

    def loadData(self, table_name = 'db'):
        df = pd.read_sql_query(f"SELECT * FROM `{table_name}`", self.conn)
        # print(df.info)
        return df


db_manager = DBManager(database='./database')

if __name__ == "__main__":
    # load old data
    db_manager.showData("db")
    # scrape new data (in type of pandas df)

    # insert new data

    # load new data
