[![Try it on Nbviewer](https://img.shields.io/badge/MariaDB_Statistics_2019-jupyter_notebook-blue?logo=jupyter)](https://nbviewer.jupyter.org/github/MariaDB/mariadb.org-tools/blob/master/reporting/MDBF_Statistics.ipynb?flush_cache=true)

# Common workflows

### Generating gitlog committers datasets
* Run Zak's [script](https://github.com/zakgreant/mariadb.org-tools/tree/master/reporting) to get a git-log CSV file
* Assuming the output CSV from the step above is named `input.csv`, run `python3 process_gitlog_csv.py -s ./input.csv -o 'dataset.csv'` to correct some mistakes in the original CSV  file.
* Dataset should be good to go in the `MariaDB_Statistics_2019` Jupyter notebook

### Generating GitHub activity datasets
* Install the [github-activity](https://github.com/choldgraf/github-activity) tool using `pip install git+https://github.com/choldgraf/github-activity`
* Run `python3 process_github_activity --since '2019-01-01' --until '2019-12-31' --auth your_github_auth_token -o ./github_dataset.csv`
