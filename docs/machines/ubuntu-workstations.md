# Ubuntu Workstations

[Ubuntu Desktop](https://ubuntu.com/download/desktop) is the operating system of choice for all workstations. Ubuntu Desktop is a free and open-source operating system. It is based on the Debian Linux distribution.

All workstations heavily rely on Docker to provide virtually every development tool. By using Docker, we can easily install and manage various development tools without worrying about dependencies or compatibility issues. This allows us to work on multiple projects simultaneously, each with its own set of specific requirements, without having to worry about conflicts.

| Workstation | Description                                                             |
| ----------- | ----------------------------------------------------------------------- |
| `caprica`   | Primary workstation for development tasks and daily to-dos              |
| `kobol`     | Secondary workstation (notebook) for development tasks and daily to-dos |

## Installation and Configuration
The installation steps are the same for all workstations.

### Create bootable USB stick with Ubuntu
- [ ] Download Ubuntu from the [Ubuntu website](https://ubuntu.com).
- [ ] Create a bootable USB stick from the downloaded iso image with a tool like [Etcher](https://www.balena.io/etcher) or the Startup Disk Creator (shipped with Ubuntu).

### Install machine from stick
The setup wizard takes care of the hostname, network settings, ssh, etc.

- [ ] When prompted for a user and password, use the username `sebastian` and the default password.
- [ ] Remember to install and activate the OpenSSH server when the wizard prompts for this!
- [ ] Do not install any further software packages. Installations take place later when Ansible provisions the system.
- [ ] Run basic setup tasks using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/components/bootstrap/basics.sh | bash -`
- [ ] Test connecting to my other Linux machines (with user "sebastian" being the user created while installing the OS).
    - [ ] `caprica` via `ssh sebastian@caprica.fritz.box`
    - [ ] `kobol` via `ssh sebastian@kobol.fritz.box`

### Install SSH Server
- [ ] Setup openssh-server using `curl https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/main/components/bootstrap/ssh-server.sh | bash -` if needed

### Configuration and package installation
- [ ] Install machine using the Ansible configs from this repo (use [ansible-cli.sh](../scripts/generated/ansible-cli-sh.md)).
- [ ] Allow machine to work with GitHub. Use public key `id_rsa.pub`, NOT the private key!

### Manual Follow-Up todos
- [ ] Set dark mode, Dock config, etc.
- [ ] Add `~/work`, `~/tmp` and `~/virtualmachines` to favorites (in File Manager)
- [ ] Update file associations in "Settings > Applications > Sublime Text"
- [ ] Install GitHub CLI extensions: `gh extension install seachicken/gh-poi`
- [ ] Use [docker-stacks-cli.sh](../scripts/generated/docker-stacks-cli-sh.md) to start Docker Compose services. Make sure you only start the Portainer Stack! Other Stacks are managed by Portainer.
- [ ] Use [components/conky/run.sh](../scripts/generated/run-sh.md) to start all conky instances.
