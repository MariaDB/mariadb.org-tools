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
Codename: lenny
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: dbart@askmonty.org

Origin: MariaDB
Label: MariaDB
Codename: squeeze
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: dbart@askmonty.org

Origin: MariaDB
Label: MariaDB
Codename: wheezy
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: dbart@askmonty.org
END

for i in "lenny debian5" "squeeze debian6" "wheezy wheezy"; do
    set $i
    reprepro --basedir=. include $1 $ARCHDIR/kvm-deb-$2-amd64/debs/binary/mariadb-*_amd64.changes
    for i in `find "$ARCHDIR/kvm-deb-$2-x86/" -name '*_i386.deb'` ; do reprepro --basedir=. includedeb $1 $i ; done
done
