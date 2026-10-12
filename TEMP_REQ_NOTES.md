# Temp Requirement Notes to feed to bmad (later)

## nginx proxy manager

instead of a traditional nginx reverse proxy ...
create issue for this

## Taskfile

Create 1 single command to run all cloud provisionings from taskfile

## Pipeline

Check with inspec or something if app is up-and-running

## Ansible

create a user for the app on the droplet to avoid running it as root

## Versions

use dependabot do watch opentofu??

## Pipeline dependencies

pipeline -> release (if semantic release determines)
   deploy github pages

app release -> dependabot update compose file -> cloud-deployment
other repo           deploy updated versions to the cloud
