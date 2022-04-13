#!/bin/bash

set -xeuv

build_deps()
{
	wget https://github.com/fmtlib/fmt/archive/refs/tags/8.0.1.tar.gz -O - | tar -zxf -
	mkdir -p build-fmt
	cd build-fmt
	cmake -DCMAKE_INSTALL_PREFIX="$HOME"/inst-fmt  -DFMT_MODULE=ON -DFMT_DOC=OFF -DFMT_TEST=OFF ../fmt-8.0.1/
	cmake --build .
	cmake --install .
	cd ..
}

build()
{
	if [ ! -d "${HOME}"/inst-fmt ]; then
		build_deps
	fi
	source=$1
	mkdir -p build
	cd build
	/opt/bin/ccache --zero-stats
	cmake ../"$source" -DCMAKE_BUILD_TYPE="$2" \
		-DCMAKE_C_LAUNCHER=/opt/bin/ccache \
		-DCMAKE_CXX_LAUNCHER=/opt/bin/ccache \
		-DCMAKE_C_COMPILER=gcc-10 \
		-DCMAKE_CXX_COMPILER=g++-10 \
		-DCMAKE_AR=/usr/bin/ar \
		-DCMAKE_PREFIX_PATH=/opt/freeware/ \
		-DCMAKE_REQUIRED_LINK_OPTIONS=-L/opt/freeware/lib \
		-DCMAKE_REQUIRED_FLAGS=-I\ /opt/freeware/include \
		-DPLUGIN_OQGRAPH=NO \
		-DWITH_UNIT_TESTS=NO \
		-DPLUGIN_S3=NO \
		-DPLUGIN_CONNECT=NO \
		-DPLUGIN_SPIDER=NO \
		-DPLUGIN_WSREP_INFO=NO \
		-DLIBFMT_INCLUDE_DIR="$HOME"/inst-fmt/include \
		-DCMAKE_LIBRARY_PATH="$HOME"/inst-fmt/lib
	make -j"$(( "$jobs" * 2 ))"
	/opt/bin/ccache --show-stats
}

mariadbtest()
{
	cat <<EOF > ../unstable-tests
type_test.type_test_double   : unknown reason
plugins.server_audit         : unknown reasons
main.cli_options_force_protocol_not_win : unknown reasons
type_inet.type_inet6         : AIX incorrect IN6_IS_ADDR_V4COMPAT implementation (reported)
main.func_json_notembedded   : machine too fast sometimes - bb-10.6-danielblack-MDEV-27955-postfix-func_json_notembedded 
binlog_encryption.rpl_typeconv : timeout on 2 minutes, resource, backtrace is just on poll loop
rpl.rpl_typeconv : timeout on 2 minutes, resource, backtrace is just on poll loop
rpl.rpl_row_img_blobs : timeout on 2 minutes, resource, backtrace is just on poll loop
main.mysql_upgrade : timeout on 2 minutes, resource, backtrace is just on poll loop
main.mysql_client_test_comp : too much memory when run in parallel (8 seems to work)
federated.* : really broken, can't load plugin
EOF
	if [[ $1 =~ mariadb-10.[567].* ]]; then
		cat <<EOF >> ../unstable-tests
innodb.log_file_name         : 10.[567] only. MDEV-14425 probably incidenly fixed it
EOF
	fi
	# for saving logs
	ln -s build/mysql-test .
	mysql-test/mysql-test-run.pl --verbose-restart --force --retry=3 --max-save-core=1 --max-save-datadir=1 \
		--max-test-fail=20 --testcase-timeout=2 --parallel="$jobs" --skip-test-list="$PWD"/../unstable-tests

}

clean()
{
	ls -ad "$@" || echo "not there I guess"
	rm -rf "$@" 2> /dev/null
}


export TMPDIR=$HOME/tmp
# gcc-10 paths found by looking at nm /opt/freeware/.../libstdc++.a | grep {missing symbol}
export LIBPATH=/opt/freeware/lib/gcc/powerpc-ibm-aix7.1.0.0/10/pthread/:/opt/freeware/lib/gcc/powerpc-ibm-aix7.1.0.0/10:/usr/lib:$PWD/build/libmariadb/libmariadb/

jobs=${4:-12}

case $1 in
	build)
		shift
		build "$@"
		;;
	test)
		mariadbtest "$2"
		;;
	clean)
		clean mariadb* build* mysql-test /mnt/packages/* /buildbot/logs/*
		;;
esac
