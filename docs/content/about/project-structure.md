# Project and Repository Structure

## Filesystem Structure
This is the structure of the repository with the most important directories and files. There is of course more in the repository, but the important parts are listed here.

```
+--+  docs
|  +---  build                 # Helper image to build MkDocs with all needed dependencies
|  +---  contents              # Actual documentation
|  +---  site                  # Generated HTML based on Markdown (ignored from git)
+--+  components
|  +---  app                   # Application source code
|  +---  ...                   # ...
+---  Dockerfile               # Multi-Stage Dockerfile for the application
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

|All Branches|

    split
        :Scan Code;
        kill
    split again
        :Build and
        Unit Tests and
        Acceptance Tests;

        :Publish Artifact as
        :<commit-sha>;
    end split

    :Publish Artifact as
    Release Candidate :rc;

    :Validate Release Candidate;

|Branch: main|
    if (release?) then (no)
        GREY:(s)
    else (yes)
        :Create Git Tag
        and GitHub Release;
    endif

|Tag|
    split
        :Publish Artifact
        as Release :latest;

        :Validate Release;
    split again
        :Build Docs Website;
        :Deploy Docs Website;
    end split

    GREY:(s)

@enduml
```

### Docker Scout Scan
We use the `docker-scout` tool to scan the Docker image for vulnerabilities. The tool is run as part of the Docker image build process in out pipeline. The tool is configured not to break the build, but to provide a report of the vulnerabilities found in the image. The report is then used to decide if the image is safe or if it needs to be fixed.

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

|Existing|
    GREY:(s)

    :Tag :latest;

    :Tag :rc;

|All Branches|
    :New Tag :<commig-sha>;

    :Docker Scout compare
    :<commig-sha> to :rc/

    :Docker Scout compare
    :<commig-sha> to :latest/

    :Docker Scout CVS
    scan for :<commig-sha>/

|Branch: main|
    :New Tag :rc;

|Tag|
    :New Tag :latest;

    :Docker Scout CVS
    scan for :latest/

    GREY:(s)

@enduml
```

## Docker Image Build
The Docker image build process is separated into multiple steps. The image is a Multi-Stage Dockerfile to ensure that the final image is as small as possible with as few dependencies as possible. Part of the build process is to run unit tests and acceptance tests to ensure that the image is working as expected. For more information, see [Dockerfile](https://github.com/sommerfeld-io/configs-homelab/blob/main/Dockerfile).
