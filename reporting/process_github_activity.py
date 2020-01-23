import argparse
import sys
import pandas as pd
from github_activity import get_activity

def setup_parser():
    DESCRIPTION = "Pull a pandas DataFrame using the github-activity tool"
    parser = argparse.ArgumentParser(description=DESCRIPTION)

    parser.add_argument(
        "-s", "--since", default='2019-01-01', help="""Get github activity stating with this date"""
    )

    parser.add_argument(
        "-u", "--until", default='2019-12-31', help="""End date for github activity"""
    )
    parser.add_argument(
        "-a", "--auth", default=None, help="""GitHub authentication token"""
    )

    parser.add_argument(
        "-o", "--output", default=None, help="""Output CSV file"""
    )
    return parser

def compute_activity(args):
    # Due to a limitation in either the Github GraphQL API or github-activity
    # tool which prevents pulling all activity at once, the hack is to get it
    # year by year and concatenate the results at the end.
    dataframes = []
    s_year,s_month,s_day = args.since.split('-')
    u_year,u_month,u_day = args.until.split('-')
    for y in range(int(s_year), int(u_year) + 1):
        # Make sure we start with the date passed by the user
        day = month = '01'
        if y == int(s_year):
            day, month = s_day, s_month
        interval_start = '-'.join([str(y), month, day])

        # Make sure we end with the date passed by the user
        day, month = '31', '12'
        if y == int(u_year):
            day, month = u_day, u_month
        interval_end = '-'.join([str(y), month, day])

        df = get_activity('MariaDB/server',
                          since=interval_start,
                          until=interval_end,
                          kind='pr',
                          auth=args.auth)
        dataframes.append(df)

    dataframes.reverse()
    return pd.concat(dataframes, sort=False, ignore_index=True)

def main():
    parser = setup_parser()
    args = parser.parse_args(sys.argv[1:])

    df = compute_activity(args)

    if args.output:
        df.to_csv(args.output)
        return
    print(df)

if __name__ == "__main__":
    main()
