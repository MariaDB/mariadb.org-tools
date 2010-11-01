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

# Base directory where SysBench files are found.
BASE="${HOME}/work"
TEST_DIR="${BASE}/monty_program/sysbench/sysbench/tests/db"

# We need SysBench >= v0.5.
SYSBENCH='/usr/local/bin/sysbench'

# We need bzr >= 1.18.1.
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

# Other binaries.
SUDO=/usr/bin/sudo

# Directories.
TEMP_DIR='/tmp'
DATA_DIR="${TEMP_DIR}/data"

# Where to compile the sources.
WORK_DIR='/tmp'

# Which concurrency level(s) we want to profile with OProfile.
#
# Example: profile 8 and 32.
# DO_OPROFILE='8 32'
#DO_OPROFILE='64'
# There is no OProfile on Mac OS X.
DO_OPROFILE=''

# SysBench tests to run.
SYSBENCH_TESTS[0]="delete.lua"
SYSBENCH_TESTS[1]="insert.lua"
SYSBENCH_TESTS[2]="oltp_complex_ro.lua"
SYSBENCH_TESTS[3]="oltp_complex_rw.lua"
SYSBENCH_TESTS[4]="oltp_simple.lua"
SYSBENCH_TESTS[5]="select.lua"

# Default option is --random-points=10.
SYSBENCH_TESTS[6]="select_random_points.lua"

# Default options are
#   --number-of-ranges=10
#   --random-ranges-delta=5.
SYSBENCH_TESTS[7]="select_random_ranges.lua"
SYSBENCH_TESTS[8]="update_index.lua"
SYSBENCH_TESTS[9]="update_non_index.lua"
