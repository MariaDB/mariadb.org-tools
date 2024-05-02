from flask import Flask
import mariadb
import os
import time

app = Flask(__name__)


def db_connection(host):
    # Connect to MariaDB Platform
    conn = mariadb.connect(
        user=os.getenv("MARIADB_USER"),
        password=os.getenv("MARIADB_PASSWORD"),
        host=host,
        port=3306,
        database=os.getenv("MARIADB_DATABASE")
    )
    table='sales'
    cur = conn.cursor()
    start = time.perf_counter()
    cur.execute(f"SELECT SUM(quantity * value) FROM {table} where `date` > date_sub(now(), interval 1 day);")
    end = time.perf_counter()
    return {'sales': cur.fetchone()[0], 'time' : end - start}

@app.route("/")
def hello_world():
    pop = os.getenv("POP").lower()
    if pop == 'dub':
        otherpop = 'dfw'
    else:
        otherpop = 'dub'
    try:
        result_local = db_connection("db-euus-" + pop + "-0")
        result_remote1 = db_connection("db-euus-" + otherpop + "-0")
    except mariadb.Error as e:
        return f"<p>Database error {e}</p>", 400

    return """<h1>Sales for branch at pop {} for the last day</h1>
<p>Current Local Sales:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>

<p>Current sales connecting to pop {}:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>
""".format(pop,
           result_local['sales'], result_local['time'],
           otherpop,
           result_remote1['sales'], result_remote1['time'],
           )
