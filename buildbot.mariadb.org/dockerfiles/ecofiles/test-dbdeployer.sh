#!/bin/bash

set -xeuvo pipefail

numargs=$#

fail_ifnot()
{
	if [ $numargs -lt $1 ]
	then
		echo "insufficent arguments - $1 argument minimum expected"
		exit 1
	fi
}

fail_ifnot 1

case "${1}" in
	dbdeployerfetch)
		# todo - respect version
		curl -sf https://gobinaries.com/datacharmer/dbdeployer | PREFIX=. sh
		./dbdeployer --version
		;;
	init)
		fail_ifnot 2
		mkdir /tmp/opt
		./dbdeployer init --skip-all-downloads --skip-shell-completion --sandbox-home=/tmp/sandboxes --sandbox-binary=/tmp/opt
		file=/tmp/$(basename "${2}")
                [ -f "$file" ] ||  curl --output "${file}" "$2"
                ./dbdeployer unpack --prefix=ma "${file}"
                rm "${file}"
		;;
	deploy)
		fail_ifnot 3
		./dbdeployer "$1" "$2" "${3/mariadb-/}"
		;;
	*)
		./dbdeployer $@
		;;
esac

