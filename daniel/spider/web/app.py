from flask import Flask
import mariadb
import os
import time

app = Flask(__name__)


def db_connection(table):
    # Connect to MariaDB Platform
    conn = mariadb.connect(
        user=os.getenv("MARIADB_USER"),
        password=os.getenv("MARIADB_PASSWORD"),
        host="db-euus-" + os.getenv("POP").lower() + "-0",
        port=3306,
        database=os.getenv("MARIADB_DATABASE")
    )
    cur = conn.cursor()
    start = time.perf_counter()
    cur.execute(f"SELECT SUM(quantity * value) FROM {table}")
    end = time.perf_counter()
    return {'sales': cur.fetchone()[0], 'time' : end - start}

@app.route("/")
def hello_world():
    try:
        result_local = db_connection('sales')
        result_remote1 = db_connection('sales_remote_node1')
        result_remote2 = db_connection('sales_remote_node2')
    except mariadb.Error as e:
        return f"<p>Database error {e}</p>", 400

    return """<p>Hello, World!</p>
<p>Current Local Sales:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>

<p>Current Node1 Sales:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>

<p>Current Node2 Sales:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>
""".format(result_local['sales'], result_local['time'],
           result_remote1['sales'], result_remote1['time'],
           result_remote2['sales'], result_remote2['time'],
           )
