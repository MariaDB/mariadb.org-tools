#! /bin/sh

set -eux

GALERA="$1"                       # copy in galera packages? 'yes' or 'no'
ENTERPRISE="$2"                   # is this an enterprise release? 'yes' or 'no'
REPONAME="$3"                     # name of the dir, usually 'ubuntu'
ARCHDIR="$4"                      # path to the packages

eval $(gpg-agent --daemon)

#ubuntu_dists="lucid precise quantal saucy trusty"
ubuntu_dists="lucid precise saucy trusty"
#ubuntu_dists="precise saucy trusty"
#ubuntu_dists="precise trusty"
galera_versions="25.3.5"
#galera_versions="25.3.5 25.2.9"
#galera_versions="25.3.2 25.2.8"
#galera_versions="25.3.2"

#jemalloc_dir="/home/dbart/jemalloc"
jemalloc_dir="/ds413/vms-customizations/"

if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <galera_pkgs?> <enterprise?> <reponame> <archive directory>"
    echo 1>&2 "example: $0 yes no ubuntu /media/backup/archive/pack/10.0/build-1234"
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
Codename: lucid
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}

Origin: ${origin}
Label: MariaDB
Codename: precise
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}

Origin: ${origin}
Label: MariaDB
Codename: saucy
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}

Origin: ${origin}
Label: MariaDB
Codename: trusty
Architectures: amd64 i386 source
Components: main
Description: ${description}
SignWith: ${sign_with}
END

for dist in ${ubuntu_dists}; do
  echo ${dist}
  reprepro --basedir=. include ${dist} $ARCHDIR/kvm-deb-${dist}-amd64/debs/binary/mariadb-*_amd64.changes
  for file in $(find "$ARCHDIR/kvm-deb-${dist}-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done

  case  ${dist} in
    "lucid")
      #mkdir -vp pool/main/j/jemalloc
      #rsync -av ${jemalloc_dir}/jemalloc-${dist}-amd64/jemalloc*orig.tar.bz2 pool/main/j/jemalloc/
      #reprepro --basedir=. include ${dist} ${jemalloc_dir}/jemalloc-${dist}-amd64/jemalloc*_amd64.changes




      for file in $(find "${jemalloc_dir}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "${jemalloc_dir}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      #for file in $(find "${jemalloc_dir}/jemalloc-debs/" -name '*.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
    "precise")
      #mkdir -vp pool/main/j/jemalloc
      #rsync -av ${jemalloc_dir}/jemalloc-${dist}-amd64/jemalloc*orig.tar.bz2 pool/main/j/jemalloc/
      #reprepro --basedir=. include ${dist} ${jemalloc_dir}/jemalloc-${dist}-amd64/jemalloc*_amd64.changes




      for file in $(find "${jemalloc_dir}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "${jemalloc_dir}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      #for file in $(find "${jemalloc_dir}/jemalloc-debs/" -name '*.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
    "quantal")
      #mkdir -vp pool/main/j/jemalloc
      #rsync -av ${jemalloc_dir}/jemalloc-${dist}-amd64/jemalloc*orig.tar.bz2 pool/main/j/jemalloc/
      #reprepro --basedir=. include ${dist} ${jemalloc_dir}/jemalloc-${dist}-amd64/jemalloc*_amd64.changes




      for file in $(find "${jemalloc_dir}/${dist}-amd64/" -name '*_amd64.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      for file in $(find "${jemalloc_dir}/${dist}-i386/" -name '*_i386.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      #for file in $(find "${jemalloc_dir}/jemalloc-debs/" -name '*.deb'); do reprepro --basedir=. includedeb ${dist} ${file} ; done
      ;;
    * )
      echo "no custom jemalloc packages for ${dist}"
      ;;
  esac

  #for file in $(find "/home/dbart/galera/" -name '*.deb' -not -name '*wheezy*'); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
  if [ ${GALERA} = "yes" ]; then
    for gv in ${galera_versions}; do
      for file in $(find "/home/dbart/galera-${gv}/" -name "*${dist}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb ${dist} ${file} ; done
    done
  fi
done

md5sum ./pool/main/*/*/*.deb >> md5sums.txt

