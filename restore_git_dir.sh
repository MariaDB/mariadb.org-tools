#!/bin/bash
# This script should be run from root directory of one of the git
# repositories restored from tag made by list created by backup_git_dirs.sh
#
# It takes a lot of time

echo ""
echo " *** checkout not copied files *** "
echo ""

for filename in $( git status --short|grep '^ D '|sed 's/^ D //' ) ; do
  echo "$filename"
  git checkout $filename
done

echo ""
echo " *** delete files deleted in backuped repository *** "
echo ""

for filename in $( egrep -v '(^/|\./|/\.\.$|/\.$|^\.\.$|^\.$|~|\*|\;|>|<|,|\|)' .backup_deleted_files_by_git_backup ) ; do
  echo "$filename"
  rm "$filename" 
done

echo ""
echo " *** done *** "
echo ""

