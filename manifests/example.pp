# The actual configuration class for the chroot example setup
#
class chroot::example::configure {
  # Create the additional group
  chroot::configure::create_group { [
    $chroot::example::www_group,
  ] : }
  # Copy the existing host system user to the chroot environment
  chroot::configure::copy_nchroot_user { $chroot::example::www_user :
    group => chroot::example::www_group,
    require => Chroot::Configure::Create_group [ chroot::example::www_group ],
  }
  # The chroot users need to be able to use git in this example.
  chroot::configure::install_app { [
    'git-core',
  ] : }

  # We mount a host directory in the chroot environment for the chroot users
  # to interact with. Ideally the owners and groups are the same as the chroot
  # user and group accounts. See above group and user creation/copy.
  chroot::configure::mount_dir { "/var/www/sites/virtual/example.com" : }

  # This is the global configuration for all following chroot users
  Chroot::Configure::Create_user {
    addl_group => $chroot::example::www_group,
  }
  # This creates one user called 'chroot-tester' on both the host and the chroot
  # environment.
  # In order to test this right you need to create this user on a seperate
  # machine then generate a public key and add the information here.
  chroot::configure::create_user { "chroot-tester" :
    ssh_key => "djfa;sdhg;anhgan;lgbvnalrng';nalnf;lbnadlnvgb;anga;sldfng;alngv;lndsgvlg;lajn",
  }
}

# Super class for chroot example - handles global and class variables
#
# $www_user : A host system user we want in the chroot environment to be present
#             as well.
# $www_group : A host system group we want in the chroot environment to be present
#             as well. This is an addl_group.
#
class chroot::example (
  $www_user = 'www',
  $www_group = 'www',
) {
  class { "chroot::example::configure" : }
}
