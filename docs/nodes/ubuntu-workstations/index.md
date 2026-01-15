# Ubuntu Workstations - Setup Guide

[Ubuntu Desktop](https://ubuntu.com/download/desktop) is the operating system of choice for all workstations. Ubuntu Desktop is a free and open-source operating system. It is based on the Debian Linux distribution.

| Workstation | Description                                                          |
| ----------- | -------------------------------------------------------------------- |
| `caprica`   | Secondary workstation for development tasks and daily to-dos         |
| `kobol`     | Tertiary workstation (laptop) for development tasks and daily to-dos |
| `picon`     | Primary workstation (laptop) for development tasks and daily to-dos  |

## Create bootable USB stick with Ubuntu

- [ ] Download Ubuntu from the [Ubuntu website](https://ubuntu.com).
- [ ] Create a bootable USB stick from the downloaded iso image with a tool like [Etcher](https://www.balena.io/etcher) or the Startup Disk Creator (shipped with Ubuntu).

## Install machine from stick

The setup wizard takes care of the hostname, network settings, etc.

- [ ] When prompted for a user and password, use the username `sebastian` and the default password.
- [ ] Do not install any other software packages. Installations take place later when Ansible provisions the system.
- [ ] When running Ansible from the freshly provisioned machine: Run basic setup tasks using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/basics.sh | bash -` (skip of another host is the Ansible controller)
- [ ] Setup openssh-server using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/bootstrap/ssh-server.sh | bash -` if needed
- [ ] Test connecting to my other Linux machines (with user "sebastian" being the user created while installing the OS).
    - [ ] `ssh sebastian@caprica.fritz.box`
    - [ ] `ssh sebastian@kobol.fritz.box`
    - [ ] `ssh sebastian@picon.fritz.box`
- [ ] Setup password-less ssh connections via from `caprica`, `kobol`, `picon` and `admin-pi`. Allowing password-less ssh connections to itself is essential for Ansible to work properly.
    - [ ] `ssh-copy-id sebastian@caprica.fritz.box` (to allow Ansible runs against this host)
    - [ ] `ssh-copy-id sebastian@kobol.fritz.box` (to allow Ansible runs against this host)
    - [ ] `ssh-copy-id sebastian@picon.fritz.box` (to allow Ansible runs against this host)
    - [ ] `ssh-copy-id sebastian@admin-pi.fritz.box`
    - [ ] `ssh-copy-id sebastian@runner-04-pi.fritz.box`
    - [ ] `ssh-copy-id sebastian@runner-05-pi.fritz.box`
    - [ ] `ssh-copy-id sebastian@runner-06-pi5.fritz.box`

## Configuration and package installation

- [ ] When running Ansible against Ubuntu 25.10 machines, disable sudo password prompts for the `sebastian` user. **Note:** This means you won't be prompted for a password when running `sudo` at all.
    - [ ] `ssh sebastian@<hostname>.fritz.box` (connect to the new machine)
    - [ ] `sudo visudo` (edit sudoers file)
    - [ ]  Add this line at the end of the file: `sebastian ALL=(ALL) NOPASSWD: ALL`
- [ ] Install machine using the Ansible configs from this repo using `task`.
    - [ ] [Playbook "ubuntu-desktop"](../../ansible/ubuntu-desktop.md)
    - [ ] Allow the machine to interact with GitHub. Use public key `id_rsa.pub`, NOT the private key!
    - [ ] [Playbook "repositories"](../../ansible/repositories.md)
    - [ ] Login to Docker registry on the new machine: `docker login`
    - [ ] [Playbook "telemetry-exporters"](../../ansible/telemetry-exporters.md)

## Manual Follow-Up Todos

- [ ] Set dark mode, Dock config, etc.
- [ ] Add `~/work`, `~/tmp` and `~/virtualmachines` to favorites (in File Manager)
- [ ] Update file associations in "Settings > Applications > Sublime Text"
- [ ] Install GitHub CLI extensions: `gh extension install seachicken/gh-poi`

### Configure a keyboard shortcut to open a terminal in VSCode

For example, if you want to use `Ctrl+Shift+T` as the shortcut to open a new terminal, you would press those keys when editing the shortcut. Please note that the keys you choose for the shortcut should not conflict with existing shortcuts. If they do, you will need to change or disable the conflicting shortcuts.

- [ ] Open the Keyboard Shortcuts editor by pressing `Ctrl+K Ctrl+S` or by navigating to `File > Preferences > Keyboard Shortcuts`.
- [ ] In the search box, type "terminal" to filter the commands related to the terminal.
- [ ] Look for the command `workbench.action.terminal.new` which is the command to open a new terminal.
- [ ] Click on the pencil icon next to the command to edit the shortcut. Press the keys you want to use as the shortcut, then press `Enter` to save.
