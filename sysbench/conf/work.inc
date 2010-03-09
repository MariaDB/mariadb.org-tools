# Configuration file for host: work
# 
# OS: openSUSE 11.1 (x86_64)
# Platform: x86_64
# CPU: Two socket quad-core Intel Xeon @ 3.00GHz
# RAM: 8GB
# Disk(s): 1 x WDC WD2500JS-00NCB1 S-ATA

#
# Adjust the following paths according to your installation.
#

# We need sysbench >= v0.5.
SYSBENCH='/usr/local/bin/sysbench'

# We need bzr >= 1.18.1
BZR='/usr/local/bin/bzr'

# OProfile binaries.
OPCONTROL='/usr/bin/opcontrol'

# System statistic binaries.
IOSTAT='/usr/bin/iostat'
IOSTAT_DEVICE='/dev/sda'
# For CPU utilization statistics
MPSTAT='/usr/bin/mpstat'

# Other binaries.
SUDO=/my/local/bin/sur

# Directories.
TEMP_DIR="${HOME}/tmp"
DATA_DIR="${TEMP_DIR}/data"

# Where to compile the sources.
WORK_DIR='/tmp'
