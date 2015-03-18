#! /bin/sh
#===============================================================================
#
#          FILE:  mkrepo-ubuntu.sh
# 
#         USAGE:  $0 <galera_pkgs?> <enterprise?> <reponame> <archive_dir>
# 
#   DESCRIPTION:  A script to generate the Ubuntu repositories for MariaDB
#                 Ubuntu packages.
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
REPONAME="$3"                     # name of the dir, usually 'ubuntu'
ARCHDIR="$4"                      # path to the packages
P8_ARCHDIR="$5"                   # path to p8 packages (optional)

#-------------------------------------------------------------------------------
#  Variables which are not set dynamically (because they don't change often)
#-------------------------------------------------------------------------------
galera_versions="25.3.9"                          # Version of galera in repos
galera_dir="/ds413/galera"                        # Location of galera pkgs
jemalloc_dir="/ds413/vms-customizations/jemalloc" # Location of jemalloc pkgs
at_dir="/ds413/vms-customizations/advance-toolchain/" # Location of at pkgs
ubuntu_dists="lucid precise trusty utopic"
#ubuntu_dists="lucid precise trusty"
architectures="amd64 i386 source"

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
    echo 1>&2 "example: $0 yes no ubuntu /media/backup/archive/pack/10.0/build-1234"
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
  gpg_key="signing-key@mariadb.com"            # new enterprise key (2014-12-18)
  #gpg_key="0xce1a3dd5e3c94f49"                # new enterprise key (2014-12-18)
  p8_architectures="amd64 ppc64el source"      # add ppc64el, drop i386
  suffix="signed-ent"
else
  origin="MariaDB"
  description="MariaDB Repository"
  gpg_key="package-signing-key@mariadb.org"     # mariadb.org signing key
  #gpg_key="0xcbcb082a1bb943db"                 # mariadb.org signing key
  p8_architectures="amd64 i386 source"
  suffix="signed"
fi

mkdir "$REPONAME"
cd "$REPONAME"
mkdir conf
cat >conf/distributions <<END
Origin: ${origin}
Label: MariaDB
Codename: lucid
Architectures: ${architectures}
Components: main
Description: ${description}
SignWith: ${gpg_key}

Origin: ${origin}
Label: MariaDB
Codename: precise
Architectures: ${architectures}
Components: main
Description: ${description}
SignWith: ${gpg_key}

Origin: ${origin}
Label: MariaDB
Codename: trusty
Architectures: ${p8_architectures}
Components: main
Description: ${description}
SignWith: ${gpg_key}

Origin: ${origin}
Label: MariaDB
Codename: utopic
Architectures: ${architectures}
Components: main
Description: ${description}
SignWith: ${gpg_key}
END

for dist in ${ubuntu_dists}; do
  echo ${dist}
  case ${dist} in 
    'trusty'|'utopic')
      reprepro --basedir=. include ${dist} $ARCHDIR/kvm-deb-${dist}-amd64/debs/binary/mariadb-*_amd64.changes
      ;;
    * )
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.dsc'); do reprepro --basedir=. includedsc ${dist} ${file} ; done
      for file in $(find "$ARCHDIR/kvm-deb-${dist}-amd64/" -name '*.gz'); do reprepro --basedir=. includedsc ${dist} ${file} ; done
      ;;
  esac

  if [ "${ENTERPRISE}" != "yes" ]; then
    for file in $(find "$ARCHDIR/kvm-deb-${dist}-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
  fi

  if [ "${ENTERPRISE}" = "yes" ]; then
    if [ "${dist}" = "trusty" ]; then
      if [ ! -d "${P8_ARCHDIR}" ] ; then
        echo 1>&2 "! I can't find the directory for Power 8 debs! '${P8_ARCHDIR}'"
        exit 1
      else
        for file in $(find "${P8_ARCHDIR}/p8-trusty-deb/" -name '*_ppc64el.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
        for file in $(find "${at_dir}/${dist}-ppc64el-${suffix}/" -name '*_ppc64el.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
    fi
  fi

  # Add in custom jemalloc packages for distros that need them
  case ${dist} in
    "lucid")
      for file in $(find "${jemalloc_dir}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${jemalloc_dir}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    "precise")
      for file in $(find "${jemalloc_dir}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${jemalloc_dir}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    "quantal")
      for file in $(find "${jemalloc_dir}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      if [ "${ENTERPRISE}" != "yes" ]; then
        for file in $(find "${jemalloc_dir}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      fi
      ;;
    * )
      echo "no custom jemalloc packages for ${dist}"
      ;;
  esac

  # Copy in galera packages if requested
  if [ ${GALERA} = "yes" ]; then
    for gv in ${galera_versions}; do
      if [ "${ENTERPRISE}" = "yes" ]; then
        #for file in $(find "${galera_dir}/galera-${gv}-${suffix}/" -name "*${dist}*amd64.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
        reprepro --basedir=. include ${dist} ${galera_dir}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_amd64.changes
      else
        #for file in $(find "${galera_dir}/galera-${gv}-${suffix}/" -name "*${dist}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
        reprepro --basedir=. include ${dist} ${galera_dir}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_amd64.changes
        reprepro --basedir=. include ${dist} ${galera_dir}/galera-${gv}-${suffix}/deb/galera-3_${gv}-${dist}*_i386.changes
      fi
    done
  fi
done

# Create md5sums of .deb packages
md5sum ./pool/main/*/*/*.deb >> md5sums.txt

