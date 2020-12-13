#!/bin/bash

set -xeuvo pipefail

if [ $# -lt 2 ]
then
	echo "insufficent arguments - two arguments minimum expected"
	exit 1
fi


# Asset ID for download:
# curl -L -s -H 'Accept: application/vnd.github.v3+json' https://api.github.com/repos/datacharmer/dbdeployer/releases/latest | grep -B 4 linux.tar.gz\"
case "${1}" in
	dbdeployerfetch)
		f=dbdeployer-1.57.0.linux
		[ -f "/tmp/$f" ] || \
			curl -L -s -H 'Accept: application/octet-stream' https://api.github.com/repos/datacharmer/dbdeployer/releases/assets/"${2}" \
			| tar -zxf - -C /tmp
		ln -s /tmp/"$f" dbdeployer
		./dbdeployer --version
		;;
	init)
		mkdir /tmp/opt
		./dbdeployer init --skip-all-downloads --skip-shell-completion --sandbox-home=/tmp/sandboxes --sandbox-binary=/tmp/opt
		file=/tmp/$(basename "${2}")
                [ -f "$file" ] ||  curl --output "${file}" "$2"
                ./dbdeployer unpack --prefix=ma "${file}"
                rm "${file}"
		;;
	deploy)
		./dbdeployer "$1" "$2" "${3/mariadb-/}"
		;;
	*)
		./dbdeployer $@
		;;
esac

