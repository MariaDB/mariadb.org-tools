# Metrics Tools

## Commit Metrics

We are using GitDM to process the git tree for MariaDB and generate metrics based on individuals and their affiliations. It pulls and process everything on the MariaDB tree so that commits to older branches (bug fixes) are counted.

GitDM is configured using the files in the `gitdm_config` subdirectory. The key files here help determine which company a given individual email address works for, and alises between addresses. The files are as follows:

#### domain-map

This is a catchall for an email domain name to company mapping.

#### aliases

This contains a list of email addresses which are aliases to other email addresses.

#### employers

This contains a list of email addresses which do not fit into the above categories, such as personal email addresses or individuals, to determine a given contributor's affiliation.

## PR Counts

### get_prs.py

This tool gets the PR counts for 2022 and stores them in `prs.csv`, if it is interrupted the current week number fetched is stored in `prs_start.txt` so it can continue. This also means that it can be run as a script and will only append as required when there is new data. There is a deliberate 2 second pause between each request so as not to hit the GitHub rate limit (30 requests per minute).

To execute this you will need a GitHub token from https://github.com/settings/tokens/new and set this as the environment variable `GITHUB_TOKEN`.

### plot_prs.py

This plots the new open/closed statuses for each week, using data from the `prs.csv` file. It requires `matplotlib` and `numpy` Python packages are installed (both in standard distro packages and PyPi).

### plot_totals.py

This plots the total count of open/closed PRs for each week using the data from `prs.csv`. It also requires `matplotlib` and `numpy` Python packages.
