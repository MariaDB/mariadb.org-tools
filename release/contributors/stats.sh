#!/bin/sh

git config mailmap.file individuals
git log mariadb-10.3.5..mariadb-10.3.6 --no-merges --format="%aN"|sort -u
git config mailmap.file --unset
