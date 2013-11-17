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
Codename: lucid
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org

Origin: MariaDB
Label: MariaDB
Codename: precise
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org

Origin: MariaDB
Label: MariaDB
Codename: quantal
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org

Origin: MariaDB
Label: MariaDB
Codename: raring
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org

Origin: MariaDB
Label: MariaDB
Codename: saucy
Architectures: amd64 i386 source
Components: main
Description: MariaDB Repository
SignWith: package-signing-key@mariadb.org
END

for x in lucid precise quantal raring saucy; do
  echo $x
  reprepro --basedir=. include $x $ARCHDIR/kvm-deb-$x-amd64/debs/binary/mariadb-*_amd64.changes
  for i in $(find "$ARCHDIR/kvm-deb-$x-x86/" -name '*_i386.deb'); do reprepro --basedir=. includedeb $x $i ; done
  #for file in $(find "/home/dbart/galera/" -name '*.deb' -not -name '*wheezy*'); do reprepro -S optional -P misc --basedir=. includedeb $x ${file} ; done
  for file in $(find "/home/dbart/galera/" -name "*${x}*.deb"); do reprepro -S optional -P misc --basedir=. includedeb $x ${file} ; done
done

