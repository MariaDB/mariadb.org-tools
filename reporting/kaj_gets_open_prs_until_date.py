import argparse
import sys
import pandas as pd
from github_activity import get_activity

from process_github_activity import setup_parser, compute_activity

def main():
    parser = setup_parser()
    args = parser.parse_args(sys.argv[1:])

    df = compute_activity(args)
    ts_now = pd.to_datetime(args.until, utc=True)

    def to_ts(row):
        closed = pd.to_datetime(row['closedAt'], utc=True)
        created = pd.to_datetime(row['createdAt'], utc=True)
        row['closedAt'] = closed
        row['createdAt'] = created
        return row
    df = df.apply(to_ts, axis=1)

    stillopen = df.loc[df['state'] == 'OPEN']
    were_open_now_closed = df.loc[df['state'].isin(['CLOSED', 'MERGED'])].loc[df['closedAt'] > ts_now]

    df = pd.concat([stillopen, were_open_now_closed], sort=False, ignore_index=True)

    def tr(row):
        row['openTimeDays'] = (ts_now - row['createdAt']).total_seconds() / (3600 * 24)
        return row

    df = df.apply(tr, axis=1)

    if args.output:
        df.to_csv(args.output)
        return
    print(df)

if __name__ == "__main__":
    main()
