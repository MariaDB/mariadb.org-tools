Files containing ldd output are optionally used for minor upgrade tests.

Among other checks, minor upgrade tests compare the ldd output of the current
build to the previous release and fail if it differs.

Sometimes dependencies get changed intentionally between minor releases.
We don't want tests to keep failing until the release, so we create these
baselines to be used temporarily. If a file is present, ldd output
will be compared to it instead of the previous release.

The files should be removed after the modified version has been released.

Naming rules
------------

File name

ldd.<major version>.<distro>.<arch>
e.g.
ldd.10.5.xenial.x86

Distros:

CentOS 6,8 is named as centos6, centos8
CentOS 7 is named as centos7x (centos73, centos74, etc.)
OpenSUSE 15 is named as opensuse150
SLES 12 is named as sles12
SLES 15 is named as sles150
Fedora is named as fedoraNN
Ubuntu/Debian is named by first version name (xenial, bionic,...)

Architectures:

x86_64 is named amd64

For Ubuntu/Debian:
- x86 is named i386
- ppc64le is named ppc64el

For CentOS:
- x86 is named as is
- ppc64le is named as is
- aarch64 is named as is
- ppc64 is named as is
