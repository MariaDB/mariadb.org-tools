# This file is for storing all utility functions used within buildbot's master.cfg
# The goal is to clean up the master.cfg such that only basic declarative logic is
# needed in master.cfg
def checkoutUsingGitWorktree():
    return ShellCommand(
             name="fetch_using_git",
             description="fetching using git",
             descriptionDone="fetch and git checked out...done",
             haltOnFailure=True,
             command=["bash", "-xc", util.Interpolate("""
  d=/mnt/packages/
  cd "$d"
  revision="%(prop:revision)s"
  branch="%(prop:branch)s"
  basebranch=${branch#*-}
  basebranch=${basebranch%%-*}
  [ ! -d mariadb-server ] && git clone https://github.com/MariaDB/server.git mariadb-server

  # PR? curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/MariaDB/server/pulls/333  | jq .base.ref
  # git fetch origin "$branch"?
  [[ $basebranch =~ [0-9]+\.[0-9]+ ]] || exit 1
  if [ ! -d mariadb-server-$basebranch ]
  then
      cd mariadb-server
      git worktree add ../mariadb-server-$basebranch $basebranch
      git submodule update --init --recursive --jobs 6
      cd ..
  fi

  cd mariadb-server-$basebranch
  git fetch origin
  git clean -dfx
  git checkout $revision
  git submodule update --recursive
""")])

