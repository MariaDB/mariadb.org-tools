#! /bin/sh
#===============================================================================
#
#          FILE:  mkrepo-debian.sh
# 
#         USAGE:  $0 <galera_pkgs?> <enterprise?> <reponame> <archive_dir>
# 
#   DESCRIPTION:  A script to generate the Debian repositories for MariaDB
#                 Debian packages.
#
#                 The script copies files from the archive directory into
#                 separate directories for each distribution/cpu combination
#                 (just like they are stored in the archive directory). For
#                 best results, it should be run within an empty directory.
#
#                 After running the script, the directories are uploaded to the
#                 mirrors, replacing the previous version in that series (i.e.
#                 the 10.0.15 files are replaced by the 10.0.16 files and the
#                 10.1.1 files are replaced by the 10.1.2 files, and so on).
# 
#===============================================================================

# Right off the bat we want to log everything we're doing and exit immediately
# if there's an error
set -ex
  # -e  Exit immediately if a simple command exits with a non-zero status,
  #     unless the command that fails is part of an until or  while loop, part
  #     of an if statement, part of a && or || list, or if the command's return
  #     status is being inverted using !.  -o errexit
  #
  # -x  Print a trace of simple commands and their arguments after they are
  #     expanded and before they are executed.

#-------------------------------------------------------------------------------
#  Set command-line options
#-------------------------------------------------------------------------------
GALERA="$1"                       # copy in galera packages? 'yes' or 'no'
ENTERPRISE="$2"                   # is this an enterprise release? 'yes' or 'no'
REPONAME="$3"                     # name of the dir, usually 'debian'
ARCHDIR="$4"                      # path to the packages

#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------
galera_versions="25.3.5"                    # Version of galera in repos
jemalloc_dir="/ds413/vms-customizations"    # Location of custom jemalloc pkgs
galera_dir="/ds413/galera"                  # Location of custom galera pkgs


#-------------------------------------------------------------------------------
#  Main Script
#-------------------------------------------------------------------------------
# Get the GPG daemon running so we don't have to keep entering the password for
# the GPG key every time we sign a package
eval $(gpg-agent --daemon)

# At this point, all variables should be set. Print a usage message if the
# ${ARCHDIR} variable is not set (the last of the command-line variables).
if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <galera_pkgs?> <enterprise?> <reponame> <archive_dir>"
    echo 1>&2 "example: $0 yes no debian /media/backup/archive/pack/10.0/build-1234"
    exit 1
fi

# After this point, we tread unset variables as an error
set -u
  # -u  Treat unset variables as an error when performing parameter expansion.
  #     An error message will be written to the standard error, and a
  #     non-interactive shell will exit.

# If this is an "Enterprise" MariaDB release, sign with the mariadb.com key,
# otherwise, sign with the mariadb.org key
if [ "${ENTERPRISE}" = "yes" ]; then
  origin="MariaDB Enterprise"
  description="MariaDB Enterprise Repository"
  sign_with="signing-key@mariadb.com"
else
  origin="MariaDB"
  description="MariaDB Repository"
  sign_with="package-signing-key@mariadb.org"
fi

mkdir "$REPONAME"
cd "$REPONAME"
mkdir conf
cat >conf/distributions <<END
Origin: ${origin}
Label: MariaDB
Codename: squeeze
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}

Origin: ${origin}
Label: MariaDB
Codename: wheezy
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}

Origin: ${origin}
Label: MariaDB
Codename: sid
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}
END

for i in "squeeze debian6" "wheezy wheezy" "sid sid"; do
  set $i
  echo $1
  reprepro --basedir=. include $1 $ARCHDIR/kvm-deb-$2-amd64/debs/binary/mariadb-*_amd64.changes
  for i in $(find "$ARCHDIR/kvm-deb-$2-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb $1 $i ; done

  # Add in custom jemalloc packages for distros that need them
  case  ${2} in
    "debian6")
      for i in $(find "${jemalloc_dir}/${2}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${1} ${i} ; done
      for i in $(find "${jemalloc_dir}/${2}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${1} ${i} ; done
      ;;
    * )
      echo "no custom jemalloc packages for ${1}"
      ;;
  esac

  # Copy in galera packages if requested
  if [ ${GALERA} = "yes" ]; then
    for gv in ${galera_versions}; do
      for file in $(find "${galera_dir}/galera-${gv}/" -name "*${1}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
    done
  fi
done

# Create md5sums of .deb packages
md5sum ./pool/main/*/*/*.deb >> md5sums.txt

