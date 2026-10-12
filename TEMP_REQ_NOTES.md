# Temp Requirement Notes to feed to bmad (later)

## nginx proxy manager

instead of a traditional nginx reverse proxy ...
create issue for this

## Pipeline

Check with inspec or something of app is up-and-running

## Ansible

create a user for the app to avoid runnig it as root

## Folders

move folders `ansible`, `bootstrap` and `tests` into the new folder `configs-homelab`.
rename `cloud-configs` into `configs-cloud`.

## Versions

use dependabot do watch opentofu??

## Pipeline dependencies

pipeline -> release (if semantic release determines)
   deploy github pages

app release -> dependabot update compose file -> cloud-deployment
other repo           deploy updated versions to the cloud
