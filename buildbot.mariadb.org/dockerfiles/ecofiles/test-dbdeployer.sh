#!/bin/bash

set -xeuvo pipefail

if [ $# -lt 2 ]
then
	echo "insufficent arguments - two arguments minimum expected"
	exit 1
fi

case "${1}" in
	dbdeployerfetch)
		# todo - respect version
		curl -sf https://gobinaries.com/datacharmer/dbdeployer | PREFIX=. sh
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

