#!/bin/bash
#
# This script make list to be used with tar which backup the directory tree
# in which there are git repositories and working dirs of git not deeper
# than certain depth (parameter)
#
# Parameters:
# $1 - path
# $2 - depth
#
# Example:
# backup_git_dirs.sh  /home/sanja/maria/ 2 |tar cvzf /backup/maria201908141444.tar.gz --files-from=- 
#
# Note:
#
# This script detect git repo or working dir by directory or file .git,
# in this case it backup .git, all files in git status except deleted,
# and create file .backup_deleted_files_by_git_backup with files
# deleted in the repository and also list this file.
#
# Files and directory out of detected git repo listed up to the selected
# depth to be also backuped.
#
# Empty directories are not listed.
#
# To restore backups un-tar them in the path they was (tar created with path
# from root (/)), run restore_git_dir.sh in each git repository
# (will take some time).


if [ "$1" = "" ] ; then
  echo "usage:"
  echo "  $0 <path> <depth>"
  exit 1
fi

if [ "$2" = "" ] ; then
  DEPTH=0
else
  DEPTH=$2
fi


DIR=`readlink -f $1`


if [ -e "$DIR/.git" ] ; then
  # it is git repository (or working tree)
  echo "$DIR/.git"
  # It is possible to have a submodule in the changed files so better call
  # this scrit to process it
  for filename in $( cd $DIR && git status --short |grep -v '^ D '|sed 's/^ *//'|cut -d" " -f2- ) ; do
    $0 "$DIR/$filename" 0
  done
  # list of deleted files
  $( cd $DIR && git status --short |grep '^ D '|sed 's/^ D //' > .backup_deleted_files_by_git_backup )
  echo "$DIR/.backup_deleted_files_by_git_backup"
  exit 0
fi

if [ $DEPTH -lt 1 ] ; then
  # it is too deep => just print the path
  echo "$DIR"
  exit 0
fi

# decrease depth and process fieles in the directory one by one
((DEPTH--))

for filename in $DIR/.* $DIR/*; do
  if [ ! -e $filename ] ; then
    # probably it is an emply directory and we get $DIR/*
    # we do not store empty dirs
    continue
  fi
  FILE=`basename "$filename"`
  if [ "$FILE" = "." -o "$FILE" = ".." ] ; then
    continue
  elif [ -d "$filename" ] ; then
    $0 "$filename" "$DEPTH"
  else
    echo "$filename"
  fi
done
