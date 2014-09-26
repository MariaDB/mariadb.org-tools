#! /bin/sh

set -eux

GALERA="$1"                       # copy in galera packages? 'yes' or 'no'
ENTERPRISE="$2"                   # is this an enterprise release? 'yes' or 'no'
REPONAME="$3"                     # name of the dir, usually 'debian'
ARCHDIR="$4"                      # path to the packages

eval $(gpg-agent --daemon)

#galera_versions="25.3.5 25.2.9"
galera_versions="25.3.5"
#galera_versions="25.3.2 25.2.8"
#galera_versions="25.3.2"

#jemalloc_dir="/home/dbart/jemalloc"
jemalloc_dir="/ds413/vms-customizations/"

if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <galera_pkgs?> <enterprise?> <reponame> <archive directory>"
    echo 1>&2 "example: $0 yes no debian /media/backup/archive/pack/10.0/build-1234"
    exit 1
fi

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

#for i in "wheezy wheezy"; do
for i in "squeeze debian6" "wheezy wheezy" "sid sid"; do
#for i in "squeeze debian6" "wheezy wheezy"; do
  set $i
  echo $1
  reprepro --basedir=. include $1 $ARCHDIR/kvm-deb-$2-amd64/debs/binary/mariadb-*_amd64.changes
  for i in $(find "$ARCHDIR/kvm-deb-$2-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb $1 $i ; done

  case  ${2} in
    "debian6")
      #mkdir -vp pool/main/j/jemalloc
      #rsync -av ${jemalloc_dir}/jemalloc-${2}-amd64/jemalloc*orig.tar.bz2 pool/main/j/jemalloc/
      #reprepro --basedir=. include ${1} ${jemalloc_dir}/jemalloc-${2}-amd64/jemalloc*_amd64.changes


      
      for i in $(find "${jemalloc_dir}/${2}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${1} ${i} ; done
      for i in $(find "${jemalloc_dir}/${2}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${1} ${i} ; done
      #for i in $(find "${jemalloc_dir}/jemalloc-debs/" -name '*.deb'); do reprepro --basedir=. includedeb ${1} ${i} ; done
      ;;
    * )
      echo "no custom jemalloc packages for ${1}"
      ;;
  esac

  #if [ "${1}" = "wheezy" ]; then
  #  for file in $(find "/home/dbart/galera/" -name '*wheezy*.deb'); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
  #else
  #  for file in $(find "/home/dbart/galera/" -name '*.deb' -not -name '*wheezy*'); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
  #fi
  #for file in $(find "/home/dbart/galera/" -name "*${1}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
  if [ ${GALERA} = "yes" ]; then
    for gv in ${galera_versions}; do
      for file in $(find "/home/dbart/galera-${gv}/" -name "*${1}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
    done
  fi
done

md5sum ./pool/main/*/*/*.deb >> md5sums.txt

