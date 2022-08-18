import numpy as np
import matplotlib.pyplot as plt
import csv

date = []
pull_requests_open = []
pull_requests_closed = []

with open("prs.csv", newline='') as f:
    reader = csv.reader(f)
    first = True
    for row in reader:
        if first:
            first = False
        else:
            date.append(row[0])
            pull_requests_open.append(int(row[5]))
            pull_requests_closed.append(int(row[4]))

fig = plt.figure(tight_layout=True, figsize=[12.8, 9.6])

ax1 = fig.subplots()
color = 'tab:red'
ax1.set_xlabel('Week Ending')
ax1.set_ylabel('Open PR Count')
ax1.plot(date, pull_requests_open, color=color)
ax1.tick_params(axis='y', labelcolor=color)

ax2 = ax1.twinx()
color = 'tab:blue'
ax2.set_ylabel('Closed PR Count')
ax2.plot(date, pull_requests_closed, color=color)
ax2.tick_params(axis='y', labelcolor=color)


plt.setp(ax1.get_xticklabels(), rotation=30, ha="right")

plt.savefig("prs_total.png", format='png')
