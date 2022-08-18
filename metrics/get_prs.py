import requests
import json
import datetime
import time
import os


GITHUB_TOKEN = os.environ['GITHUB_TOKEN']

auth_header = {'Authorization': 'token ' + GITHUB_TOKEN}
start_wn = 1

if os.path.exists("prs_start.txt"):
    f = open("prs_start.txt", "r")
    start_wn = int(f.read())
    f.close()

wn = datetime.datetime.today().isocalendar().week

def call_github(url):
    request = requests.get(url, headers = auth_header)

    if request.status_code != 200:
        print("Failed to get PR count")
        exit()

    pr_data = json.loads(request.text)
    count = pr_data['total_count']
    # Avoid 30 requests per minute limit
    time.sleep(2)
    return count

if os.path.exists("prs.csv"):
    f = open("prs.csv", "a")
else:
    f = open("prs.csv", "w")
    f.write('Week Ending,New PRs,Closed PRs,Merged PRs,Total PRs,Still Open PRs\n')

for d in range(start_wn, wn) :
    week = '2022-W' + str(d)
    r = datetime.datetime.strptime(week + '-1', "%Y-W%W-%w")
    start_date = r.strftime('%Y-%m-%d')
    end_date = (r + datetime.timedelta(days=6.9)).strftime('%Y-%m-%d')
    totals_end_date = (r + datetime.timedelta(days=7.9)).strftime('%Y-%m-%d')
    open_url = 'https://api.github.com/search/issues?q=repo:MariaDB/server%20is:pr%20created:' + start_date + '..' + end_date + '&per_page=1'
    closed_url = 'https://api.github.com/search/issues?q=repo:MariaDB/server%20is:pr%20is:closed%20closed:' + start_date + '..' + end_date + '&per_page=1'
    merged_url = 'https://api.github.com/search/issues?q=repo:MariaDB/server%20is:pr%20is:merged%20closed:' + start_date + '..' + end_date + '&per_page=1'

    total_open_url = 'https://api.github.com/search/issues?q=repo:MariaDB/server%20is:pr%20created:<' + totals_end_date + '&per_page=1'
    total_close_url = 'https://api.github.com/search/issues?q=repo:MariaDB/server%20is:pr%20closed:<' + totals_end_date + '&per_page=1'

    open_count = call_github(open_url)
    close_count = call_github(closed_url)
    merged_count = call_github(merged_url)
    total_open_count = call_github(total_open_url)
    total_close_count = call_github(total_close_url)

    f.write('{},{},{},{},{},{}\n'.format(end_date, open_count, close_count - merged_count, merged_count, total_open_count, total_open_count - total_close_count))
    # Save position in case an API error causes crash, also allows an early
    # re-run to become a null-op
    fs = open("prs_start.txt", "w")
    fs.write("{}".format(d+1))
    fs.close()
f.close()

