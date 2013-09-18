#! /bin/sh

set -e

REPONAME="$1"
ARCHDIR="$2"

if [ ! -d "$ARCHDIR" ] ; then
    echo 1>&2 "Usage: $0 <reponame> <archive directory>"
    exit 1
fi

mkdir "$REPONAME"
cd "$REPONAME"
mkdir conf
cat >conf/distributions <<END
Origin: MariaDB
Label: MariaDB
Codename: squeeze
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org

Origin: MariaDB
Label: MariaDB
Codename: wheezy
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org
END

for i in "squeeze debian6" "wheezy wheezy"; do
    set $i
    echo $1
    reprepro --basedir=. include $1 $ARCHDIR/kvm-deb-$2-amd64/debs/binary/mariadb-*_amd64.changes
    for i in $(find "$ARCHDIR/kvm-deb-$2-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb $1 $i ; done
    #if [ "${1}" = "wheezy" ]; then
    #  for file in $(find "/home/dbart/galera/" -name '*wheezy*.deb'); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
    #else
    #  for file in $(find "/home/dbart/galera/" -name '*.deb' -not -name '*wheezy*'); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
    #fi
    for file in $(find "/home/dbart/galera/" -name "*${1}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb $1 ${file} ; done
done
