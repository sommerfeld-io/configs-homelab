# Introduction to Homelab Configs

[doc-website]: https://sommerfeld-io.github.io/configs-homelab
[github-repo]: https://github.com/sommerfeld-io/configs-homelab
[file-issues]: https://github.com/sommerfeld-io/configs-homelab/issues
[project-board]: https://github.com/orgs/sommerfeld-io/projects/1/views/1

This project contains infrastructure configurations and docs for my workstations, servers and RasPi nodes. All infrastructure follows the infrastructure as code pattern.

![Project Logo](https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/refs/heads/main/.assets/logo.png)

Our goal is to automate as much of the infrastructure management as possible. All provisioning, configuration, and deployment tasks are handled automatically using a combination of infrastructure-as-code, provisioning, and GitOps tools. The only manual step required (at the most) is to trigger a script or workflow or some other form of automation tool. From this point on, the remainder of the process is fully automated.

- [Documentation Website][doc-website]
- [Github Repository][github-repo]
- [Sonarcloud Code Quality and Security Analysis](https://sonarcloud.io/project/overview?id=sommerfeld-io_configs-homelab)
- [Where to file issues][file-issues]
- [Project Board for Issues and Pull Requests][project-board]

## Requirements and Features

- Install all necessary software on workstations and servers. Follow Infrastructure as Code (IaC) principles. Ansible is used for this purpose.
- Every machine runs services (some of them are mandatory for every machine). These services mostly run inside Docker containers. The containers are controlled through scripts from this project.

## Warning: This Setup has Opinions (and will Enforce Them)

For obvious reasons, it's not recommended to apply this configuration directly to your personal machine. Doing so will overwrite your existing setup, which may lead to unexpected behavior.

Feel free to use this repository as a starting point for your own configuration. To stay on the safe side, it's best to experiment with it on a disposable virtual machine first.

The `main` branch is intended for Ubuntu 25.04 and later.

## Architecture Constraints

Workstations, servers and RasPi nodes are using similar operating systems.

- Every workstation and server is using Ubuntu as operating system.
- Every RasPi node is using Raspberry Pi OS (which is based on Debian) or Ubuntu Server as operating system.

This is a constraint that is not likely to change in the future.

## Contact

Feel free to contact me via <sebastian@sommerfeld.io> or [raise an issue in this repository][file-issues].
