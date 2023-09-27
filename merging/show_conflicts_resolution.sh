#!/bin/bash
#
# Usage: show_conflicts_resolution.sh prev_commit cur_branch res_branch
# Where
# prev_commit - commit we want to merge
# cur_branch  - the branch where we are going merge to
# res_branch  - the branch with resolved conflicts, based on cur_branch
#
# Example:
# ./show_conflicts_resolution.sh 275f434392d6e04ece74ddec70abde75c6d86603 mariadb-cs/10.5 mariadb-cs/bb-10.5-MDEV-25163

PREV_COMMIT=$1
CUR_BRANCH=$2
RES_BRANCH=$3

git checkout $CUR_BRANCH
git cherry-pick -x $PREV_COMMIT
if [[ $? -ne 0 ]]
then
  git add -u
  git -c core.editor=true cherry-pick --continue
  git checkout -f HEAD^ .
  git show $RES_BRANCH | patch -p1
  git diff HEAD
else
  echo "Hurrah! No conflicts."
fi
