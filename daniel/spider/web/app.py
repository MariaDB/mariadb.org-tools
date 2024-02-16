from flask import Flask
import mariadb
import os
import time

app = Flask(__name__)


def db_connection(tabble):
    # Connect to MariaDB Platform
    conn = mariadb.connect(
        user=os.getenv("MARIADB_USER"),
        password=os.getenv("MARIADB_PASSWORD"),
        host=os.getenv("MARIADB_HOST"),
        port=3306,
        database=os.getenv("MARIADB_DATABASE")
    )
    cur = conn.cursor()
    start = time.perf_counter()
    cur.execute("SELECT SUM(quantity * value) FROM {table}")
    end = time.perf_counter()
    return {'sales': cur.fetchone()[0], 'time' : start - end}

@app.route("/")
def hello_world():
    try:
        result_local = db_connection('sales')
        result_remote = db_connection('sales_remote_node1')
    except mariadb.Error as e:
        return "<p>Database error {e}</p>", 400

    return """<p>Hello, World!</p>
<p>Current Local Sales:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>
""".format(result_local['sales'], result_local['time'], result_remote['sales'], result_remote['time'])
