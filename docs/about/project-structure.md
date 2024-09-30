# Project and Repository Structure

## Filesystem Structure
This is the structure of the repository with the most important directories and files. There is of course more in the repository, but the important parts are listed here.

```
+--+  docs
|  +---  contents              # Actual documentation
|  +---  site                  # Generated HTML based on Markdown (ignored from git)
+--+  components
|  +---  ansible               # Ansible playbookds and tasks to configure machines
|  +---  bootstrap             # Bash scripts to install the most basic tools to be able to run e.g. Ansible
|  +---  conky                 # Conky Config for Ubuntu Desktop workstations
|  +---  docker-stacks         # Docker Compose stacks for services running on machines
|  +---  minikube              # Minikube configuration for local Kubernetes development
|  +---  ...                   # ...
+---  docker-compose.yml       # Docker Compose file with the toolchain (e.g. for local development)
```

## Pipeline
The build pipeline is triggered by a commit to any branch in the repository. But not all branches are treated equally. The `main` branch is the most important branch in the repository. It is the branch that is always deployable and is the branch that is used to deploy to production. Other branches use a subset of the pipeline to ensure that they can be merged into the `main` branch and are are in a deployable state.

```kroki-plantuml
@startuml
!define PURPLE #4051B5
!define WHITE #ffffff
!define GREY #e2e4e9
!define DARK_GREY #1e2129

skinparam backgroundColor transparent
skinparam DefaultFontColor e2e4e9
skinparam ArrowColor e2e4e9

skinparam ActivityBackgroundColor PURPLE
skinparam NoteFontColor DARK_GREY
skinparam NoteBackgroundColor GREY
skinparam DecisionBackgroundColor PURPLE
skinparam ForkBackgroundColor PURPLE

skinparam StartBackgroundColor GREY
skinparam EndBackgroundColor GREY

skinparam activity {
    'FontName Ubuntu
    FontName Roboto
}

|Scheduled|
    GREY:(s)
    :Dependabot;

|All Branches|
    start
    split
        :Run Linters;
    split again
        :Generate Docs;
    end split

|Branch: main|
    if (release?) then (no)
        GREY:(s)
    else (yes)
        :Create Git Tag
        and GitHub Release;
    endif

|Tag|
    :Build Docs Website;
    :Deploy Docs Website;

    GREY:(s)

@enduml
```
