#!/bin/bash
#
# We grab the user-ID from the 'host'-OS so the user-IDs match in the chroot
# environment before we create a new chroot user.
#
# This script must be run from the host-system!
#
# Usage: ./create-chroot-user.sh <chroot_directory> <user-home-directory> \
#           <main-group-name> <user-name> <additional-group-name>
#

MYUID=`cat /etc/passwd | grep "${4}:" | awk '{split($NF,values,":"); print (values[3])}'`;

# In case the user does not exist on the host-system;
# This should never be the case !?
if [ -z "$MYUID" ]; then
  chroot $1 adduser --home $2 --ingroup $3 $4
else
  chroot $1 adduser --home $2 --ingroup $3 --uid $MYUID $4
fi

# If we have an additional group specified we assign the user to it here.
if [ -n "$5" ]; then
  chroot $1 adduser $4 $5;
fi