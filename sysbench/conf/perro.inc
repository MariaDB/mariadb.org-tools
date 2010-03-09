# Configuration file for host: perro
# 
# OS: openSUSE 11.1 (x86_64)
# Platform: x86_64
# CPU: Quad-core Intel @ 3.20GHz
# RAM: 2GB
# Disk(s): 2 x ST31000528AS S-ATA as software RAID 0

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
TEMP_DIR='/mnt/data/sysbench'
DATA_DIR="${TEMP_DIR}/data"

# Where to compile the sources.
WORK_DIR='/tmp'
