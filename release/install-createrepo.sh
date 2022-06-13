#!/bin/bash - 
#===============================================================================
#
#          FILE: install-createrepo.sh
# 
#         USAGE: ./install-createrepo.sh 
# 
#   DESCRIPTION: simple script to install createrepo on Ubuntu focal
# 
#===============================================================================

set -o nounset                              # Treat unset variables as an error
set -x

sudo apt update
wget \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/c/createrepo/createrepo_0.10.3-1_all.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/d/deltarpm/deltarpm_3.6+dfsg-1build8_amd64.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/d/deltarpm/python-deltarpm_3.6+dfsg-1build8_amd64.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/p/python-lzma/python-lzma_0.5.3-4_amd64.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/u/urlgrabber/python-urlgrabber_3.10.2-1_all.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/y/yum/yum_3.4.3-3_all.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/y/yum-metadata-parser/python-sqlitecachec_1.1.4-1_amd64.deb

sudo apt install -y ./*.deb

