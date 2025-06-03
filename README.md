# Introduction to Homelab Configs

[doc-website]: https://sommerfeld-io.github.io/configs-homelab
[github-repo]: https://github.com/sommerfeld-io/configs-homelab
[file-issues]: https://github.com/sommerfeld-io/configs-homelab/issues
[project-board]: https://github.com/orgs/sommerfeld-io/projects/1/views/1

This project contains infrastructure configurations and docs for my workstations, servers and RasPi nodes. All infrastructure follows the infrastructure as code pattern.

![Project Logo](https://raw.githubusercontent.com/sommerfeld-io/configs-homelab/refs/heads/main/docs/.assets/images/logo/logo.png)

- [Documentation Website][doc-website]
- [Github Repository][github-repo]
- [Sonarcloud Code Quality and Security Analysis](https://sonarcloud.io/project/overview?id=sommerfeld-io_configs-homelab)
- [Where to file issues][file-issues]
- [Project Board for Issues and Pull Requests][project-board]

## Requirements and Features

This section outlines the basic requirements and features of the project. These requirements serve as a guideline for the development of the application and provide a clear overview of the expected functionality.

- Install all necessary software on workstations and servers. Follow Infrastructure as Code (IaC) principles. Ansible is used for this purpose.
- Every machine runs services (some of them are mandatory for every machine). These services mostly run inside Docker containers. The containers are controlled through scripts from this project.

## Warning: This Setup Has Opinions (and Will Enforce Them)

For obvious reasons, it's not recommended to apply this configuration directly to your personal machine. Doing so will overwrite your existing setup, which may lead to unexpected behavior.

Feel free to use this repository as a starting point for your own configuration. To stay on the safe side, it's best to experiment with it on a disposable virtual machine first.

The main branch is intended for Ubuntu 24.10 and later.

## Architecture Constraints

Workstations, servers and RasPi nodes are using similar operating systems.

- Every workstation and server is using Ubuntu as operating system.
- Every RasPi node is using Raspberry Pi OS (which is based on Debian) or Ubuntu Server as operating system.

This is a constraint that is not likely to change in the future.

## Contact

Feel free to contact me via <sebastian@sommerfeld.io> or [raise an issue in this repository][file-issues].
