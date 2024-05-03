from flask import Flask, stream_with_context
import mariadb
import os
import time
import socket

app = Flask(__name__)

cname = socket.gethostbyname_ex("self.metadata.compute.edgeengine.io")[0]

print(cname)

(instance, deployment, target, workload, stack, rootdomain) = cname.split(".", 6)

alldeployments = os.getenv("DEPLOYMENTS").lower().split(",")

def db_connection(host):
    # Connect to MariaDB Platform
    conn = mariadb.connect(
        user=os.getenv("MARIADB_USER"),
        password=os.getenv("MARIADB_PASSWORD"),
        host=host,
        port=3306,
        database=os.getenv("MARIADB_DATABASE"),
    )
    cur = conn.cursor()
    start = time.perf_counter()
    cur.execute(
        "SELECT SUM(quantity * value) FROM sales where `date` > date_sub(now(), interval 1 day)"
    )
    end = time.perf_counter()
    return {"sales": cur.fetchone()[0], "time": end - start}


@app.route("/")
def hello_world():
    def generate():
        yield f"<h1>Sales for branch at {deployment} for the last day</h1>"

        for dep in alldeployments:
            try:
                result = db_connection("db-" + target + "-" + dep + "-0")
                yield """
<p>Current sales connecting to {}:</p>
<p>{}</p>
<p></p>
<p>Time for request {}</p>
""".format(
                    dep, result["sales"], result_local["time"]
                )

            except mariadb.Error as e:
                return f"<p>Database error {e}</p>", 400

    return stream_with_context(generate())


@app.route("/ping")
def ping():
    return "All is well"
