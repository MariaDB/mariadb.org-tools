# Configuration file for host: au0013
# 
# OS: Mac OS X 10.6.2
# Platform: x86_64
# CPU: Dual-core Intel Core 2 Duo @ 2.8GHz
# RAM: 4GB
# Disk(s): 1 x ST9500420ASG S-ATA

#
# Adjust the following paths according to your installation.
#

# We need sysbench >= v0.5.
SYSBENCH='/usr/local/bin/sysbench'

# We need bzr >= 1.18.1
BZR='/usr/local/bin/bzr'

# OProfile binaries.
# There is no OProfile on Mac OS X.
# TODO: Find OProfile equivalent for Mac OS X.
OPCONTROL=''

# System statistic binaries.
IOSTAT='/usr/sbin/iostat'
IOSTAT_DEVICE='disk0'
# Note: sar works different on Mac OS X.
SAR='/usr/bin/sar'

# Directories.
TEMP_DIR='/tmp'
DATA_DIR="${TEMP_DIR}/data"

# Where to compile the sources.
WORK_DIR='/tmp'