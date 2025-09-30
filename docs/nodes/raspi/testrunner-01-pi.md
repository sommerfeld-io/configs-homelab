# `testrunner-01-pi.fritz.box`

The `testrunner-01-pi` is a Raspberry Pi 4B with 4GB of RAM and a 128GB microSD card. It is used for testing and development purposes in the home lab.

## Setup

To automate the setup of `testrunner-01-pi`, should run the following Ansible playbooks:

- [ ] [Playbook "raspi"](../../ansible/raspi.md)
- [ ] [Playbook "telemetry-exporters"](../../ansible/telemetry-exporters.md)

Running these playbooks ensures a consistent, repeatable, and fully documented deployment process for your monitoring infrastructure.

- [ ] Setup password-less ssh connections from `carpica`, `kobol` and `admin-pi`
    - [ ] `ssh-copy-id sebastian@testrunner-01-pi.fritz.box`
