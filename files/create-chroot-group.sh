#!/bin/bash
#
# We grab the group-ID from the 'host'-OS so the group-IDs match in the chroot
# environment before we create a new chroot group.
#
# This script must be run from the host-system!
#
# Usage: ./create-chroot-group.sh <chroot_directory> <group-name>
#

MYGID=`cat /etc/group | grep "${2}:" | awk '{split($NF,values,":"); print (values[3])}'`;

# In case the group does not exist on the host system we just assign a new GID
if [ -z "$MYGID" ]; then
  chroot $1 addgroup $2;
else
  chroot $1 addgroup --gid $MYGID $2
fi