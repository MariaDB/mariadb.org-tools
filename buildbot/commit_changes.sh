#!/bin/bash - 
#===============================================================================
#
#          FILE:  commit_changes.sh
# 
#         USAGE:  ./commit_changes.sh 
# 
#   DESCRIPTION:  This script is for auto-commiting changes to the
#                 maria-master.cfg file (or any other file specified). It
#                 should be run once per day via cron. The script must be run
#                 from the repository directory where ${file} is located.
# 
#===============================================================================

set -o nounset                              # Treat unset variables as an error

#-------------------------------------------------------------------------------
#  variables
#-------------------------------------------------------------------------------

age=7200 # how old, in seconds, the file must be to auto-commit; 7200 = 2 hours
#file="maria-master.cfg"  # The file this script is monitoring
files="maria-master.cfg
       builders/bld_xenial_valgrind.py
       builders/cc-installation.py
       builders/connectors-buildsteps.py
       builders/rpm_fact_extra_steps.py
       builders/server-installation.py
       builders/zyp_fact_extra_steps.py
       builders/__init__.py
       builders/conncpp/linux_builders.py
       builders/conncpp/windows_builder.py
       builders/conncpp/src_builder.py
       builders/odbc/__init__.py
       builders/odbc/linux_builders.py
       builders/odbc/windows_builder.py
       builders/odbc/src_builder.py
       builders/odbccpp_builders.py
       builders/odbccpp_schedulers.py
       builders/qa/__init__.py
       builders/qa/qa_builders.py
       builders/qa/qa_schedulers.py"
repo_dir="$(pwd)"        # the repository directory, default is "$(pwd)"
prod_dir="/etc/buildbot" # the production directory, default is "/etc/buildbot"
quiet="--quiet"          # nomally "--quiet", set to "" to have more output

#-------------------------------------------------------------------------------
#  main script
#-------------------------------------------------------------------------------

for file in ${files};do
  # first check the age of the file
  if [ $(stat --format=%Y ${prod_dir}/${file}) -le $(( $(date +%s) - ${age} )) ]; then 
    # file is more than ${age} old, now see if it differs from the repo file
    git pull ${quiet}    # first make sure we have the latest version in the repo
    if [ -n "$(diff ${repo_dir}/${file} ${prod_dir}/${file})" ]; then 
      # if we are here, we need to commit changes, first copy the file over
      cp -a ${prod_dir}/${file} ${repo_dir}/${file}
      # then update the permissions
      chmod 644 ${repo_dir}/${file}
      # one last check to make sure there are differences
      if [ -n "$(git diff --raw ${file})" ]; then
        # there are changes, commit them and push to launchpad
        git commit ${quiet} -m "automatic ${file} commit" ${file}
        git push ${quiet} origin
      fi
    fi
  fi
done

