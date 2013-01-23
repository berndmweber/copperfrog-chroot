#!/bin/bash
# This file installs a minimal Ubuntu system in the chroot environment.
# Use this file from within the chroot environment.
#
# E.g. > sudo chroot /var/chroot
#      > /root/configure-lucid.sh
#

export HOME=/root
export LOG=/tmp/install.log

# Tag the log file with a date.
echo "Current Date:" > $LOG;
date &>> $LOG;
echo;

# Run an update to make sure Ubuntu has the latest repository information
echo "> apt-get update" >> $LOG;
apt-get update &>> $LOG;

# Install a very basic Ubuntu system, including gpg so we can load additional
# repos and packages
echo "> apt-get -y --no-install-recommends install debconf devscripts gnupg" >> $LOG;
apt-get -y --no-install-recommends install debconf devscripts gnupg &>> $LOG;

# Update again with that information
echo "> apt-get update" >> $LOG;
apt-get update &>> $LOG;

# Now let's make sure the locales package is present
echo "> apt-get -y install locales dialog" >> $LOG;
apt-get -y install locales dialog &>> $LOG;

# Configure for locale for US. This makes sure we do not ge annoying locale
# errors on the commandline all the time.
echo "> locale-gen en_US.UTF-8" >> $LOG;
locale-gen en_US.UTF-8 &>> $LOG;

# Make sure the locale-file for the profile configuration is existing
echo "> touch /etc/profile.d/locale" >> $LOG;
touch /etc/profile.d/locale;

# Define the default locale setting for logged in users
echo "> echo export LANG=C > /etc/profile.d/locale" >> $LOG;
echo "export LANG=C" > /etc/profile.d/locale;

# Make sure the tz-file for the profile configuration is existing
echo "> touch /etc/profile.d/tz" >> $LOG;
touch /etc/profile.d/tz;

# Define the timezone of the chroot installation. PST in this case.
echo "> echo TZ='America/Los_Angeles'; export TZ > /etc/profile.d/tz" >> $LOG;
echo "TZ='America/Los_Angeles'; export TZ" > /etc/profile.d/tz;

# This ensures all locale settings are configured correctly inside the chroot
# environment
echo "> dpkg-reconfigure locales" >> $LOG;
dpkg-reconfigure locales &>> $LOG;

# Now we can install the ubuntu-minimal group
echo "> apt-get -y install ubuntu-minimal" >> $LOG;
apt-get -y install ubuntu-minimal &>> $LOG;

# Let's also make sure we're up-to-date on packages.
echo "> apt-get -y upgrade" >> $LOG;
apt-get -y upgrade &>> $LOG;

# This is it.
echo;
echo "Done." >> $LOG;

exit 0;