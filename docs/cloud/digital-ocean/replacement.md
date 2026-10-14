# Replacement

A droplet can be removed and set up again at any time. Its volume and its reserved IP stay: both have `prevent_destroy`, so OpenTofu never deletes them. The app answers at the same reserved IP again, with the same `fantasy-hockey.yml`.

## Remove the Droplet

Remove the droplet in one of two ways:

- **Manually:** destroy it in the DigitalOcean web UI. Do not tick the option that also destroys the attached volume.
- **With OpenTofu:** destroy only the droplet and its reserved IP assignment:

    ```bash
    tofu -chdir=configs-cloud/digital-ocean/opentofu apply -destroy -target='digitalocean_droplet.this["fantasy-hockey"]'
    ```

    The plan must destroy only `digitalocean_droplet.this["fantasy-hockey"]` and `digitalocean_reserved_ip_assignment.this["fantasy-hockey"]`.

Do not remove the droplet entry from `droplets.tf` to delete the droplet. The volume and the reserved IP come from the same entry, so the plan would destroy them too, and `prevent_destroy` stops it with `Resource instance cannot be destroyed`.

Changing the `image` slug in `droplets.tf` (for example for a new Ubuntu LTS) replaces the droplet in the next apply without a separate removal step. Bump the Molecule platform in `configs-cloud/digital-ocean/tests/molecule/base.yml` to the same release and run `task cloud:molecule:test` first.

## Set It Up Again

```bash
ssh-keygen -R <reserved-ip>
task cloud:digital-ocean:deploy
```

`deploy` runs `opentofu:apply`, `ansible:provision` and `ansible:deploy-fantasy-hockey` and asks for the vault password twice. The apply creates the droplet and the reserved IP assignment and updates the project resources; the volume and the reserved IP stay as they are.

DigitalOcean attaches the existing volume to the new droplet but does not mount it. The app deploy mounts it (see [Deployment](deployment.md#deploy-fantasy-hockeyyml)), finds `fantasy-hockey.yml` and does not seed it again.

## Checks

- `http://<reserved-ip>` serves the app, and `http://<reserved-ip>/metrics` returns 404.
- `ssh root@<reserved-ip> 'findmnt /mnt/prod_fantasy_hockey_data'` shows the volume.
- In Grafana Cloud, `up{job="fantasy-hockey", environment="digital-ocean", stage="prod"}` and `up{job="integrations/cadvisor", environment="digital-ocean", stage="prod"}` are `1` after the deploy. The new droplet has the same instance name as the old one, so look at samples after the deploy only.
- A second `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` reports `changed=0`.

## Volume Not Attached

The app deploy stops with "does not exist ... so the volume is not attached" when DigitalOcean did not attach the volume:

```bash
doctl compute droplet list --tag-name fantasy-hockey --format ID,Name,PublicIPv4
doctl compute volume list --format ID,Name,Size,Region,DropletIDs
doctl compute volume-action attach <volume-id> <droplet-id>
```

Then run `task cloud:digital-ocean:ansible:deploy-fantasy-hockey` again. Never format the volume (`mkfs`), that deletes the data.
