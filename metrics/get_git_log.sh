#!/bin/sh
git submodule update --init
git clone https://github.com/mariadb/server --no-tags
cd server
git log --all --numstat -M --since-as-filter="2019-01-01" --until="2020-01-01" > git-2019.log
git log --all --numstat -M --since-as-filter="2020-01-01" --until="2021-01-01" > git-2020.log
git log --all --numstat -M --since-as-filter="2021-01-01" --until="2022-01-01" > git-2021.log
git log --all --numstat -M --since-as-filter="2022-01-01" --until="2023-01-01" > git-2022.log
cd ..
gitdm/gitdm -c gitdm_config/gitdm.config -u -n < server/git-2019.log > out-2019.txt
gitdm/gitdm -c gitdm_config/gitdm.config -u -n < server/git-2020.log > out-2020.txt
gitdm/gitdm -c gitdm_config/gitdm.config -u -n < server/git-2021.log > out-2021.txt
gitdm/gitdm -c gitdm_config/gitdm.config -u -n < server/git-2022.log > out-2022.txt
