import time
import psycopg2
from psycopg2 import OperationalError

# Database connection parameters
db = "final_project"
user = "postgres"
password = "password"
host = "final-project-db.chwsiom0s6lw.eu-north-1.rds.amazonaws.com"
port = 5432

def wait_for_db():
    while True:
        try:
            conn = psycopg2.connect(
                dbname=db,
                user=user,
                password=password,
                host=host,
                port=port,
            )
            conn.close()
            print("Database is ready!")
            break
        except OperationalError:
            print("Database is not ready yet. Waiting...")
            time.sleep(1)

if __name__ == "__main__":
    wait_for_db()
