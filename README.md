# divtools
Divix Linux Config Tools

The structure for the divtools files are as follows:
\: Root files
    divtools_install.sh: Install Bash script that installs all the divtools and configures a system for use.

.ssh: contains the PUBLIC authorized_keys to be installed on all servers so I can connect
    authorized_keys: file to be installed in */.ssh folders for access

scripts: Contains common scripts for use on all systems.

dotfiles: contains various login/.* files used for configuring shells
    .bash_aliases:
    .bash_profile
    .bashrc: This is a QNAP .bashrc. Currently, it is NOT used since it is in the $skipfiles

qnap_cfg: Contains QNAP/QTS specific scripts/files to handle QNAP
    dotfiles: files that could be used by QNAP. These are defaults for QNAP.
    etc: files used to boot and config of qnap system
    scripts: scripts for managing qnap
