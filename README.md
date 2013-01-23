copperfrog-chroot
=================

Puppet module to configure a chroot environment for SSH and SFTP users.

At the moment only Ubuntu-Lucid as chroot environment is supported.

This module will create a folder with a fully functional Ubuntu-Lucid(10.04) environment. It will configure the openssh-server to chroot users belonging to a specific group (sftp).
The configuration allows for multiple groups and users to be made available in the chroot environment as well as bind-mounting specific directories inside the chroot environment.

For more information please see the inline comments.
