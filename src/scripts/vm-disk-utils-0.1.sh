#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Script Name: vm-disk-utils.sh
# Author: Trent Swanson - Full Scale 180 Inc github:(trentmswanson)
# Version: 0.1
# Last Modified By:       Trent Swanson
# Description:
#  This script automates the partitioning and formatting of data disks
#  Data disks can be partitioned and formatted as seperate disks or in a RAID0 configuration
#  The script will scan for unpartitioned and unformatted data disks and partition, format, and add fstab entries
# Parameters :
#  1 - b: The base directory for mount points (default: /datadisks)
#  2 - s  Create a striped RAID0 Array (No redundancy)
#  3 - h  Help
# Note :
# This script has only been tested on Ubuntu 12.04 LTS and must be root

help()
{
    echo "Usage: $(basename $0) [-b data_base] [-h] [-s] [-o mount_options]"
    echo ""
    echo "Options:"
    echo "   -b         base directory for mount points (default: /datadisks)"
    echo "   -s         create a striped RAID array (no redundancy)"
    echo "   -o         mount options for data disk"
    echo "   -h         this help message"
}

DEV=/dev/nvme0n1

DISK_FORMAT_OPTS="-E nodiscard "
# Base path for data disk mount points
MOUNTPOINT="/media/elasticsearchvolume"
# Mount options for data disk
MOUNT_OPTIONS="defaults,noatime,nodiratime,nodev,noexec,nosuid,nofail,nobarrier,discard"

log()
{
    echo \[$(date +%d%m%Y-%H:%M:%S)\] \["format_and_partition_disks"\] "$1"
    echo \[$(date +%d%m%Y-%H:%M:%S)\] \["format_and_partition_disks"\] "$1" >> /var/log/arm-install.log
}

export DEBIAN_FRONTEND=noninteractive

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

has_filesystem() {
    DEVICE=${1}
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}


add_to_fstab() {
    UUID=${1}
    log "calling fstab with UUID: ${UUID} and mount point: ${MOUNTPOINT}"
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        log "Not adding ${UUID} to fstab again (it's already there)"
    else
        LINE="UUID=\"${UUID}\"\t${MOUNTPOINT}\text4\t${MOUNT_OPTIONS}\t1 2"
        echo -e "${LINE}" >> /etc/fstab
    fi
}


# Create Partitions
has_filesystem "${DEV}"

if [ ${?} -ne 1 ];
then
    log "Already formatted"
    exit 0
fi

mkfs.ext4 $DISK_OPTS $DEV
mkdir -p $MOUNTPOINT
read UUID FS_TYPE < <(blkid -u filesystem ${DEV}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
add_to_fstab "${UUID}" "$MOUNTPOINT"
log "Mounting disk $DEV on $MOUNTPOINT"
mount -o $MOUNT_OPTIONS /dev/$DEV $MOUNTPOINT

echo 2 > /sys/block/nvme0n1/queue/rq_affinity
echo noop > /sys/block/nvme0n1/queue/scheduler
echo 256 > /sys/block/nvme0n1/queue/read_ahead_kb
