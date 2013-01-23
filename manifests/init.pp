# Install the necessary packages to make the chroot environment work.
#
# This ONLY works for Ubuntu Lucid (10.04) right now!
#
# $group : All chroot users will get assigned to this group. The SSHD
#          configuration will match for this group. Default is 'sftp'.
# $gid : This defines the system GID for above group. This will allow the
#        the group to be usable across multiple machines.
# $chroot_dir : The chroot direcotry where the chroot environment will be
#               installed into.
#
class chroot::install (
  $group,
  $gid,
  $chroot_dir,
) {
  # Copperfrog specific. Makes sure the basic Linux configuration is existing.
  #require ( 'linux' )
  File {
    ensure => directory,
    owner => root,
    group => root,
    mode => 644,
  }
  # Let's make sure the directories for the chroot environment and the
  # chroot users are existing.
  file { [
    $chroot_dir,
    "/home/chroot",
  ] : }

  case $::operatingsystem {
    'Ubuntu' : {
      package { [
        "dchroot",
        "debootstrap",
      ] :
        ensure => present,
        require => Class [ "linux" ],
      }
      # This creates the chroot group
      group { $group :
        ensure => present,
        gid => $gid,
      }
    }
    default : {
      alert ("OS ${::operatingsystem} is not supported by this class.\n")
    }
  }
}

# This method adds users to the host system and the chroot environment.
#
# $name : The user name to be added.
# $ssh_key : We use ssh public keys to identify users. This way no passwords
#            are required.
# $ssh_type : The type of ssh_key. Default is set to 'ssh-rsa'.
# $addl_group : Defines an additional grou pthe chroot user should be associated
#               to. Empty by default.
# $chroot_os : This defines the OS version installed in the chroot
#              environment. We grab the default form the class variable.
# $chroot_dir : The chroot direcotry where the chroot environment is
#               installed into. We grab the default form the class variable.
# $group : The main group chroot users will get assigned to. We grab the default
#          form the class variable.
#
define chroot::configure::create_user (
  $ssh_key,
  $ssh_type = "ssh-rsa",
  $addl_group = 'none',
  $chroot_os = $chroot::t_chroot_os,
  $chroot_dir = $chroot::t_chroot_dir,
  $group = $chroot::t_group,
) {
  if $addl_group == 'none' {
    $t_addl_group = ''
  } else {
    $t_addl_group = $addl_group
  }
  # Create the host system user.
  user { $name :
    ensure     => present,
    gid        => $group,
    home       => "/home/chroot/${name}",
    shell      => "/bin/bash",
    managehome => true,
    require    => Class [ "chroot::configure" ],
  }
  # Assign the SSH-key so they can log in without paswsword.
  ssh_authorized_key { $name :
    ensure => present,
    key => $ssh_key,
    type => $ssh_type,
    user => $name,
    require => [ Class [ 'linux' ], User [ $name ] ],
  }
  # Now create the same user in the chroot environment.
  exec { "create-chroot-user-${name}" :
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "${chroot_dir}/root/create-chroot-user.sh ${chroot_dir} /home/chroot/${name} ${group} ${name} ${t_addl_group}",
    unless => "grep ${name} ${chroot_dir}/etc/passwd",
    require => User [ $name ],
  }
}

# This method copies existing host system users to the chroot environment.
#
# $name : The user account to be copied.
# $group : The main group this users will get assigned to. Must be fined and
#          doesn't have to (shouldn't) be the chroot group.
# $chroot_os : This defines the OS version installed in the chroot
#              environment. We grab the default form the class variable.
# $chroot_dir : The chroot direcotry where the chroot environment is
#               installed into. We grab the default form the class variable.
#
define chroot::configure::copy_nchroot_user (
  $group,
  $chroot_os = $chroot::t_chroot_os,
  $chroot_dir = $chroot::t_chroot_dir,
) {
  exec { "create-chroot-user-${name}" :
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "${chroot_dir}/root/create-chroot-user.sh ${chroot_dir} /home/chroot/${name} ${group} ${name}",
    unless => "grep ${name} ${chroot_dir}/etc/passwd",
    require => Class [ "chroot::configure" ],
  }
}

# This method creates a group in the chroot environment. It will copy an
# existing group if it exists in the host system.
#
# $name : The group to be created/copied.
# $chroot_os : This defines the OS version installed in the chroot
#              environment. We grab the default form the class variable.
# $chroot_dir : The chroot direcotry where the chroot environment is
#               installed into. We grab the default form the class variable.
#
define chroot::configure::create_group (
  $chroot_os = $chroot::t_chroot_os,
  $chroot_dir = $chroot::t_chroot_dir,
) {
  exec { "create-chroot-group-${name}" :
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "${chroot_dir}/root/create-chroot-group.sh ${chroot_dir} ${name}",
    unless => "grep ${name} ${chroot_dir}/etc/group",
    require => Exec [ "configure-${chroot_os}" ],
  }
}

# This method creates a bind-mount for an existing directory on the host
# system inside the chroot environment. This makes it possible to make
# specific portions of the host system available to chrooted users.
# E.g. '/var/www/'
#
# $name : The directory to be bind-mounted inside the chroot environment.
#         If no 'target' is given this will also define the mount point
#         inside the chroot environment.
# $target : An optional target location inside the chroot environment.
# $chroot_os : This defines the OS version installed in the chroot
#              environment. We grab the default form the class variable.
# $chroot_dir : The chroot direcotry where the chroot environment is
#               installed into. We grab the default form the class variable.
#
define chroot::configure::mount_dir (
  $target = 'none',
  $chroot_os = $chroot::t_chroot_os,
  $chroot_dir = $chroot::t_chroot_dir,
) {
  # Let's determine if we have a specific target for our mount point.
  # Otherwise use the same as the source.
  if $target == 'none' {
    $dest = $name
  } else {
    $dest = $target
  }
  # This makes sure the mount point exists. We do not use 'file' here
  # because a 'mkdir -p' is a lot less complicated in case the mount
  # point is nested deep.
  exec { "create_dir_chroot_${dest}" :
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "mkdir -p ${chroot_dir}${dest}",
    creates => "${chroot_dir}${dest}",
    require => Class [ "chroot::configure" ],
  }
  # This ensures that the mount point is recreated in case of a host
  # system reboot. It enters the information in the host '/etc/fstab'.
  mount { "${chroot_dir}${dest}" :
    ensure => mounted,
    device => $name,
    options => "bind",
    fstype => "simfs",
    require => Exec [ "create_dir_chroot_${name}" ],
  }
}

# This method installs a specific application inside the chroot environment.
# E.g. 'vim', 'nano', etc.
#
# $name : The application to be installed. This must be a valid package
#         name for the chrooted OS.
# $creates : Define this if a specific file is created in the process.
# $unless : Defines a specific check to look for once the app is installed.
#           This is the fallback.
# $chroot_os : This defines the OS version installed in the chroot
#              environment. We grab the default form the class variable.
# $chroot_dir : The chroot direcotry where the chroot environment is
#               installed into. We grab the default form the class variable.
#
define chroot::configure::install_app (
  $creates = 'none',
  $unless = 'none',
  $chroot_os = $chroot::t_chroot_os,
  $chroot_dir = $chroot::t_chroot_dir,
) {
  # We need to install inside the chroot environment. So standard puppet
  # 'package' won't work here.
  Exec {
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "chroot ${chroot_dir} apt-get -y install ${name}",
    require => Exec [ "configure-${chroot_os}" ],
  }
  # Was $creates defined?
  if $creates != 'none' {
    exec { "install-app-${chroot_os}-${name}" :
      creates => $creates,
    }
  # Was $unless defined?
  } elsif $unless != 'none' {
    exec { "install-app-${chroot_os}-${name}" :
      unless => $unless,
    }
  # We fallback to asking the package manager inside the chroot environment
  # if the package is installed.
  } else {
    exec { "install-app-${chroot_os}-${name}" :
      unless => "chroot ${chroot_dir} dpkg --list | grep \"${name} \"",
    }
  }
}

# Configuration class for chroot. This configures our host and basic
# chroot environments.
#
# $group : All chroot users will get assigned to this group. The SSHD
#          configuration will match for this group.
# $gid : This defines the system GID for above group. This will allow the
#        the group to be usable across multiple machines.
# $chroot_dir : The chroot direcotry where the chroot environment will be
#               installed into.
# $chroot_os : This defines the OS version to be installed in the chroot
#              environment.
# $chroot_os_arch : The OS architecture to be installed in the chroot
#                   environment.
# $chroot_os_mirror : The mirror to be used for the very initial install of
#                     the chrooted debootstrap system.
#
class chroot::configure (
  $group,
  $gid,
  $chroot_dir,
  $chroot_os,
  $chroot_os_arch,
  $chroot_os_mirror,
) {
  Augeas {
    require => Class [ "chroot::install" ],
  }
  # This configures the ssh server to chroot users belonging to group $group.
  augeas { "sshd-configure-${group}-group" :
    context => '/files/etc/ssh/sshd_config',
    changes => [
      # chroot restricted group users
      "set Match[Condition/Group = \"${group}\"]/Condition/Group \"${group}\"",
      "set Match[Condition/Group = \"${group}\"]/Settings/ChrootDirectory \"${chroot_dir}\"",
      "set Match[Condition/Group = \"${group}\"]/Settings/AllowTcpForwarding no",
    ],
    # Copperfrog specific. Makes sure the SSH server is running/restarted.
    #notify => Service [ $linux::service::sshd_svc ],
  }
  # This configures schroot for a basic 'lucid' configuration when debootstrap
  # is run.
  augeas { "schroot-${chroot_os}-config" :
    context => '/files/etc/schroot/schroot.conf',
    lens => 'Schroot.lns',
    incl => '/etc/schroot/schroot.conf',
    changes => [
      "set lucid/description \"Ubuntu Lucid\"",
      "set lucid/location \"${chroot_dir}\"",
      "set lucid/priority \"3\"",
      "set lucid/users \"your_username\"",
      "set lucid/groups \"sbuild\"",
      "set lucid/root-groups \"root\"",
    ],
  }
  # This will install a basic Ubuntu chroot environment in $chroot_dir.
  exec { "debootstrap-${chroot_os}" :
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "debootstrap --variant=buildd --arch ${chroot_os_arch} ${chroot_os} ${chroot_dir} ${chroot_os_mirror}",
    creates => "${chroot_dir}/etc/apt/sources.list",
    require => Augeas [ "schroot-${chroot_os}-config" ],
  }
  # Make sure the proc file system is bind-mounted in the chroot environment.
  mount { "${chroot_dir}/proc" :
    ensure => mounted,
    device => "/proc",
    options => "bind",
    fstype => "proc",
    require => Exec [ "debootstrap-${chroot_os}" ],
  }
  # Make sure the dev file system is bind-mounted in the chroot environment.
  mount { "${chroot_dir}/dev" :
    ensure => mounted,
    device => "/dev",
    options => "bind",
    fstype => "dev",
    require => Exec [ "debootstrap-${chroot_os}" ],
  }
  File {
    ensure => file,
    owner => root,
    group => root,
    mode => 644,
    require => Mount [ "${chroot_dir}/proc", "${chroot_dir}/dev" ],
  }
  # Copies the resolv configuration from host to chroot environment.
  file { "${chroot_dir}/etc/resolv.conf" :
    source => "puppet:///modules/linux/resolv.conf",
  }
  # Copies the package manager configuration from host to chroot environment.
  file { "${chroot_dir}/etc/apt/sources.list" :
    source => "/etc/apt/sources.list",
  }
  # This will allow us to configure the chroot environment further.
  file { "${chroot_dir}/root/configure-${chroot_os}.sh" :
    mode => 0744,
    source => "puppet:///modules/chroot/configure-${chroot_os}.sh",
  }
  # This script will allow user creation.
  file { "${chroot_dir}/root/create-chroot-user.sh" :
    mode => 0744,
    source => "puppet:///modules/chroot/create-chroot-user.sh",
  }
  # This script will allow group creation.
  file { "${chroot_dir}/root/create-chroot-group.sh" :
    mode => 0744,
    source => "puppet:///modules/chroot/create-chroot-group.sh",
  }
  # Now we do the actual chroot configuration and minimal OS installation.
  exec { "configure-${chroot_os}" :
    path => "/bin:/sbin:/usr/bin:/usr/sbin",
    command => "chroot ${chroot_dir} /root/configure-${chroot_os}.sh",
    creates => "${chroot_dir}/etc/profile.d/locale",
    require => File [
                "${chroot_dir}/etc/resolv.conf",
                "${chroot_dir}/etc/apt/sources.list",
                "${chroot_dir}/root/configure-${chroot_os}.sh" ],
  }
  # Install some apps we really need.
  chroot::configure::install_app { [
    "wget",
    "nano",
    "vim",
    "openssh-server",
  ] : }
  # Finally create the main groups needed including the chroot group.
  chroot::configure::create_group { [
    $group,
  ] : }
}

# Super class for chroot - handles global and class variables
#
# $group : All chroot users will get assigned to this group. The SSHD
#          configuration will match for this group. Default is 'sftp'.
# $gid : This defines the system GID for above group. This will allow the
#        the group to be usable across multiple machines.
# $chroot_dir : The chroot direcotry where the chroot environment will be
#               installed into.
# $chroot_os : This defines the OS version to be installed in the chroot
#              environment. Default is 'lucid'.
# $chroot_os_arch : The OS architecture to be installed in the chroot
#                   environment. Default is 'amd64'.
# $chroot_os_mirror : The mirror to be used for the very initial install of
#                     the chrooted debootstrap system.
#
class chroot (
  $group = 'sftp',
  $gid = 1500,
  $chroot_dir = "/var/chroot",
  $chroot_os = 'none',
  $chroot_os_arch = 'none',
  $chroot_os_mirror = 'none',
) {
  # This allows for global variables assigned through the Puppet Enterprise
  # console -> chroot_group, chroot_group_id, ...
  if $::chroot_group != undef {
    $t_group = $::chroot_group
  } else {
    $t_group = $group
  }
  if $::chroot_group_id != undef {
    $t_group_id = $::chroot_group_id
  } else {
    $t_group_id = $gid
  }
  if $::chroot_dir != undef {
    $t_chroot_dir = $::chroot_dir
  } else {
    $t_chroot_dir = $chroot_dir
  }
  if $::chroot_os != undef {
    $t_chroot_os = $::chroot_os
  } else {
    if $chroot_os == 'none' {
      case $::operatingsystem {
        'Ubuntu' : {
          $t_chroot_os = 'lucid'
        }
      }
    } else {
      $t_chroot_os = $chroot_os
    }
  }
  if $::chroot_os_arch != undef {
    $t_chroot_os_arch = $::chroot_os_arch
  } else {
    if $chroot_os_arch == 'none' {
      $t_chroot_os_arch = $::architecture
    } else {
      $t_chroot_os_arch = $chroot_os_arch
    }
  }
  if $::chroot_os_mirror != undef {
    $t_chroot_os_mirror = $::chroot_os_mirror
  } else {
    if $chroot_os_mirror == 'none' {
      case $::operatingsystem {
        'Ubuntu' : {
          $t_chroot_os_mirror = 'http://mirror.tocici.com/ubuntu/'
        }
      }
    } else {
      $t_chroot_os_mirror = $chroot_os_mirror
    }
  }

  # Install necessary packages, etc.
  class { "chroot::install" :
    group => $t_group,
    gid => $t_group_id,
    chroot_dir => $t_chroot_dir,
  }
  # Configure the chroot environment
  class { "chroot::configure" :
    group => $t_group,
    gid => $t_group_id,
    chroot_dir => $t_chroot_dir,
    chroot_os => $t_chroot_os,
    chroot_os_arch => $t_chroot_os_arch,
    chroot_os_mirror => $t_chroot_os_mirror,
  }
}
