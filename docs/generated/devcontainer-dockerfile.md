# Dev Container Dockerfile

Dockerfile for the development container.

## Overview

This Dockerfile is used to build the development container for this project. It contains the
necessary instructions to create an environment with all the dependencies required for
development.

This allows you to develop and test the project in a containerized environment. The Dev
Container is based on the `ubuntu` image and contains all necessary tools to work with the
project.

However, the Dev Container is not suited to run the project's scripts. Especially the Docker
and Ansible scripts should be run on the host machine. The Dev Container is intended to be used
for development and testing purposes only.

```kroki-plantuml
@startuml
!define WHITE #e2e4e9

skinparam backgroundColor transparent
skinparam DefaultFontColor WHITE
skinparam ArrowColor WHITE

skinparam ControlBorderColor WHITE
skinparam ControlBackgroundColor transparent
skinparam ComponentBorderColor WHITE
skinparam RectangleBorderColor WHITE

skinparam activity {
'FontName Ubuntu
FontName Roboto
}

rectangle project <<workstation>> {
component dc as "Dev Container" {
control linters <<docker compose>>
}

control acli as "ansible-cle.sh"
control mcli as "docker-stacks-cli.sh"
control dcli as "minikube-cli.sh"
control Helm
}

@enduml
```

## Prerequisites
Having Visual Studio Code (VSCode) and the Dev Container plugin installed are essential
prerequisites for this development environment. Docker is also mandatory.


