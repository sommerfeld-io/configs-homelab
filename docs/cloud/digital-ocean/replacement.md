# Replacement

This page is the procedure to replace a droplet that has a reserved IP and a data volume, such as `prod-fantasy-hockey`. OpenTofu destroys the old droplet and creates a new one. The volume and the reserved IP stay: the new droplet attaches the same volume at creation and the reserved IP is assigned to it again. Provisioning and the app deploy then rebuild everything else from the repository.

The examples use `prod-fantasy-hockey` (map key `fantasy-hockey`). Run every command from the repository root with `DIGITALOCEAN_ACCESS_TOKEN` set.

## When to Replace

- **OS upgrade:** a new Ubuntu LTS image. The droplet is never upgraded in place, it is replaced from the new image.
- **Broken droplet:** a droplet that is misconfigured or damaged beyond a provision run is replaced from the same image.
- **Changed SSH key list:** keys are only injected at creation, see [Droplet](droplet.md#ssh-keys).

This procedure cannot change the `region`: the volume and the reserved IP share it, so a new region would destroy both and `prevent_destroy` refuses the plan. It does not add a first volume to a droplet either; that is described under [Apply](droplet.md#apply).

Replacing creates the new droplet only after the old one is destroyed. A second droplet next to the old one cannot take over, because a volume is attached to one droplet only. So every replacement takes the app offline, see [Outage](#outage).

## Copy the Data File

Before anything is replaced, stop the stack so the app does not write the data file any more, copy the file off the droplet and record its checksum. The copy is the fallback if the volume does not come back. It holds the pool's players and their email addresses: keep it outside the repository, readable only by you, and never commit it.

```bash
backup=~/fantasy-hockey-$(date +%F-%H%M%S).yml
echo "$backup"
ssh root@<reserved-ip> 'cd /mnt/prod_fantasy_hockey_data/fantasy-hockey && sudo -u fantasy-hockey docker compose stop && sync'
scp root@<reserved-ip>:/mnt/prod_fantasy_hockey_data/fantasy-hockey/data/fantasy-hockey.yml "$backup"
chmod 600 "$backup"
ssh root@<reserved-ip> 'sha256sum /mnt/prod_fantasy_hockey_data/fantasy-hockey/data/fantasy-hockey.yml'
sha256sum "$backup"
```

Both checksums must be equal. Note the file name of the copy, the checksum and the old droplet's own public IPv4 (`tofu -chdir=configs-cloud/digital-ocean/opentofu output droplet_ipv4_addresses`); all three are needed after the replacement. The devcontainer's home folder is not bind-mounted, so do not rebuild the devcontainer until the [checks](#checks) passed. Delete the copy after a successful check.

If the droplet is broken and does not accept SSH, there is no fresh copy: skip this step and the checksum check, and rely on the volume, which the replacement never destroys.

To start the stack again without replacing, for example when you answer anything but `yes` to the plan or the apply fails:

```bash
ssh root@<reserved-ip> 'cd /mnt/prod_fantasy_hockey_data/fantasy-hockey && sudo -u fantasy-hockey docker compose start'
```

## Trigger the Replacement

There are two ways. Both replace the droplet the same way, because a changed `image` forces a new droplet.

- **OS upgrade:** first bump the Molecule platform in `configs-cloud/digital-ocean/tests/molecule/base.yml` (`name` and `image`) to the new release and run `task cloud:molecule:test`. Then change the `image` slug of the entry in `configs-cloud/digital-ocean/opentofu/droplets.tf` (look up slugs with `doctl compute image list-distribution`) and run `task cloud:digital-ocean:opentofu:apply`. Commit both changes. To roll back, revert the slug and replace again, which means a second outage.
- **Same image (broken droplet, drill):** there is no task for `-replace`, so run OpenTofu directly:

```bash
tofu -chdir=configs-cloud/digital-ocean/opentofu apply -replace='digitalocean_droplet.this["fantasy-hockey"]'
```

## Read the Plan

Both commands print the plan and ask for confirmation. Read the plan at that prompt, before typing `yes`. Confirm only a plan in which:

- `digitalocean_droplet.this["fantasy-hockey"]` must be replaced (`-/+`): the image change, or `-replace`, forces it;
- `digitalocean_reserved_ip_assignment.this["fantasy-hockey"]` must be replaced, because it points to the new droplet ID;
- `digitalocean_project_resources.this` is updated in place, because the new droplet has a new URN;
- no other resource is created, replaced or destroyed. `digitalocean_volume.this["fantasy-hockey"]` and `digitalocean_reserved_ip.this["fantasy-hockey"]` do not appear at all.

A plan that destroys the volume or the reserved IP stops with `Resource instance cannot be destroyed` (`prevent_destroy`). Never work around that error during a replacement: answer anything but `yes`, start the stack again (see [Copy the Data File](#copy-the-data-file)) and find out what changed.

## Provision and Deploy

Run provisioning and the app deploy as separate steps, so the data file is checked before the app starts and rewrites it:

```bash
task cloud:digital-ocean:ansible:provision
```

Provisioning waits until the new droplet accepts SSH and cloud-init is done. Ansible connects to the new droplet's own public IPv4 and accepts an unknown host key (`StrictHostKeyChecking=accept-new`). If it reports a changed host key for the new IP, that address was in `known_hosts` already: remove it with `ssh-keygen -R <new-droplet-ip>` and run provisioning again.

Remove the old host keys (see [Host Keys](#host-keys)), then check the volume and the data file while the app is not started yet:

```bash
ssh root@<reserved-ip> 'findmnt /mnt/prod_fantasy_hockey_data'
ssh root@<reserved-ip> 'sha256sum /mnt/prod_fantasy_hockey_data/fantasy-hockey/data/fantasy-hockey.yml'
```

The mount must exist and the checksum must equal the one recorded before the replacement. If the volume is not mounted, see [Volume Not Mounted](#volume-not-mounted). If the file is missing or its checksum differs, see [Restore the Data File](#restore-the-data-file). Then deploy the app:

```bash
task cloud:digital-ocean:ansible:deploy-fantasy-hockey
```

The deploy finds `fantasy-hockey.yml` on the volume and does not seed it again, see [Seed Rule](deployment.md#seed-rule).

`task cloud:digital-ocean:deploy` runs the same three steps (`opentofu:apply`, `ansible:provision`, `ansible:deploy-fantasy-hockey`) in one go and asks for the vault password twice. Use it when no check is needed in between, for example for the second run below.

## Host Keys

The new droplet answers on the reserved IP with a new SSH host key. Remove the old keys of the reserved IP and of the old droplet's public IPv4 before connecting with `ssh`:

```bash
ssh-keygen -R <reserved-ip>
ssh-keygen -R <old-droplet-ip>
```

## Checks

After the deploy:

- `http://<reserved-ip>` opens the app with the pool's data.
- `curl -s -o /dev/null -w '%{http_code}\n' http://<reserved-ip>/metrics` prints `404`.
- In Grafana Cloud (Explore), both queries return `1`. The old droplet had the same instance name, so look only at samples after the deploy finished:

    ```text
    up{job="fantasy-hockey", environment="digital-ocean", stage="prod"}
    up{job="integrations/cadvisor", environment="digital-ocean", stage="prod"}
    ```

- A second `task cloud:digital-ocean:deploy` on the same day prints `No changes.` for OpenTofu and `changed=0` in both play recaps. Provisioning installs Docker with `state: latest`, so a Docker release published in between shows up as a change; that is no error.

The checksum is not compared after the deploy: the app rewrites `fantasy-hockey.yml` at runtime, so a difference then is not data loss.

## Volume Not Mounted

When the volume is not mounted, the app deploy stops before it writes anything, with the message that `/mnt/prod_fantasy_hockey_data` is not a mount point. Check the volume and mount it by hand:

```bash
doctl compute droplet list --tag-name fantasy-hockey --format ID,Name,PublicIPv4
doctl compute volume list --format ID,Name,Size,Region,DropletIDs
ssh root@<reserved-ip> 'ls -l /dev/disk/by-id/ | grep DO_Volume'
```

`DropletIDs` of the volume must show the new droplet's `ID` from the first command. If it is empty, the volume is not attached; attach it with `doctl compute volume-action attach <volume-id> <droplet-id>`. Once the device link `scsi-0DO_Volume_prod-fantasy-hockey-data` exists, mount it and make the mount permanent. Never format the volume (`mkfs`), that deletes the data.

```bash
ssh root@<reserved-ip>
mkdir -p /mnt/prod_fantasy_hockey_data
mount -o defaults,nofail,discard,noatime /dev/disk/by-id/scsi-0DO_Volume_prod-fantasy-hockey-data /mnt/prod_fantasy_hockey_data
grep -q prod_fantasy_hockey_data /etc/fstab || echo '/dev/disk/by-id/scsi-0DO_Volume_prod-fantasy-hockey-data /mnt/prod_fantasy_hockey_data ext4 defaults,nofail,discard,noatime 0 2' >> /etc/fstab
findmnt /mnt/prod_fantasy_hockey_data
```

Then repeat the checksum check from [Provision and Deploy](#provision-and-deploy) and run `task cloud:digital-ocean:ansible:deploy-fantasy-hockey`.

## Restore the Data File

Restore only when the checksum before the app deploy differs from the recorded one, or the file is missing. Use the file name recorded in [Copy the Data File](#copy-the-data-file):

```bash
backup=<recorded-copy-file>
ssh root@<reserved-ip> 'cd /mnt/prod_fantasy_hockey_data/fantasy-hockey && sudo -u fantasy-hockey docker compose stop'
scp "$backup" root@<reserved-ip>:/mnt/prod_fantasy_hockey_data/fantasy-hockey/data/fantasy-hockey.yml
ssh root@<reserved-ip> 'chown 1000:1000 /mnt/prod_fantasy_hockey_data/fantasy-hockey/data/fantasy-hockey.yml && chmod 0644 /mnt/prod_fantasy_hockey_data/fantasy-hockey/data/fantasy-hockey.yml'
ssh root@<reserved-ip> 'cd /mnt/prod_fantasy_hockey_data/fantasy-hockey && sudo -u fantasy-hockey docker compose start'
```

Before the first app deploy on the new droplet there is no stack yet: skip the `stop` and `start` lines, copy the file and run `task cloud:digital-ocean:ansible:deploy-fantasy-hockey`. If the `data/` folder does not exist yet, create it first with `mkdir -p` and `chown 1000:1000`.

## Outage

The app is offline from the moment the stack stops in [Copy the Data File](#copy-the-data-file) until the app deploy has started the new stack. In between, OpenTofu destroys the old droplet and creates the new one, cloud-init runs, provisioning installs Docker, cAdvisor and Alloy, the checks run, and the deploy pulls the app and nginx images. Plan the replacement for a time when nobody uses the pool, and note the duration of each replacement.
