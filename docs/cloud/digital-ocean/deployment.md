# Deployment

The fantasy hockey app runs as docker compose on the droplets with the tag `fantasy-hockey`: the app container and a Caddy container in front of it. Caddy serves the app over HTTPS at `https://fantasy-hockey.prod.do.sommerfeld.app` (see [Domain](domain.md)) with a Let's Encrypt certificate it obtains and renews itself. `http://` on the domain redirects to `https://`, and the reserved IP no longer serves the app. Backups and alerts are not part of this setup.

## deploy-fantasy-hockey.yml

`configs-cloud/digital-ocean/ansible/playbooks/deploy-fantasy-hockey.yml` targets the inventory group `fantasy-hockey` (one group per droplet tag, see [Provisioning](provisioning.md)). Ansible warns that the hyphen in the group name is not a valid character; this is accepted. The play connects as `root` and needs a provisioned droplet: `provision.yml` installs Docker, so the `docker` group exists before the deploy adds a user to it.

The play first mounts the droplet's data volume. DigitalOcean mounts a volume automatically only when the volume and the droplet are created together, so a replacement droplet gets the existing volume attached but not mounted:

- The device is `/dev/disk/by-id/scsi-0DO_Volume_<droplet-name>-data` (`fantasy_hockey_volume_device`) and the mount point `/mnt/<droplet_name>_data` (`fantasy_hockey_volume_mount`), both derived from the droplet name, so `prod-fantasy-hockey` gets `/mnt/prod_fantasy_hockey_data`.
- The play fails when the device does not exist (the volume is not attached). Otherwise `ansible.posix.mount` mounts the existing ext4 file system with `defaults,nofail,discard,noatime` and writes the `fstab` entry; it never formats the volume. After a new mount it refreshes the mount facts for the role's check.
- A systemd drop-in `/etc/systemd/system/docker.service.d/fantasy-hockey-volume.conf` sets `RequiresMountsFor=<fantasy_hockey_volume_mount>`, which gives `docker.service` a `Requires=` and an `After=` on the volume's mount unit. The play reloads systemd only when the drop-in changed and does not restart Docker. Without it, `nofail` lets the droplet boot without the volume, and Docker would restart the stack (`restart: unless-stopped`) before a late volume is mounted and create empty `data/` and `caddy/` folders on the root disk below the mount point. A Caddy that started on such empty folders would also order a new certificate.
- These tasks are tagged `volume`: `task cloud:digital-ocean:ansible:deploy-fantasy-hockey -- --tags volume` mounts the volume without starting the app, for example to check the data file before the app starts.

Then the play loads the secrets from the vault file with an `include_vars` task and reads the droplet's reserved IP from the DigitalOcean metadata service (`http://169.254.169.254/metadata/v1/reserved_ip/ipv4/ip_address`, reachable only on the droplet) into `fantasy_hockey_reserved_ip`. It stops when the droplet has no reserved IP. The domain `fantasy_hockey_domain` is a play variable, `<app>.<stage>.do.sommerfeld.app` derived from the droplet name `<stage>-<app>`, so `prod-fantasy-hockey` gets `fantasy-hockey.prod.do.sommerfeld.app`. The stage is the inventory's `alloy_stage`, the same value Alloy labels the droplet's series with (see [Provisioning](provisioning.md)). Then it runs the cloud role `ansible/roles/fantasy-hockey`. The role runs these steps in this order:

1. **Volume check (`tasks/main.yml`):** it fails, before anything is written, when `fantasy_hockey_volume_mount` (`/mnt/prod_fantasy_hockey_data` as role default; the play sets it from the droplet name) is not a mount point, naming the missing mount. A second check fails when `fantasy_hockey_path` is not below that mount, for example because the vault overrides it. It compares the normalized path, so a path that leaves the mount through `..` fails too. The app data must live on the volume, not on the droplet's disk.
2. **DNS check (`tasks/dns.yml`):** it resolves the domain on the droplet (`getent ahostsv4`) and fails, before anything is written, unless the addresses are exactly the reserved IP. See [DNS Check](#dns-check).
3. **User (`tasks/user.yml`):** the `docker` role of the roles collection (only `50-user`) creates the user `fantasy-hockey` with `/bin/bash` and a home folder from `/etc/skel`, and adds it to the `docker` group.
4. **Prompt (`tasks/user.yml`):** the `bash` role (only `10-bash-config`) writes the exports, aliases and the prompt to `/home/fantasy-hockey/.bashrc`. The prompt is the role default `fantasy_hockey_ps1`, the orange `ubuntu_server` prompt of the homelab without the git branch.
5. **Files (`tasks/files.yml`):** the deploy directory, the compose file, the Caddyfile and Caddy's data folders, `.env` and the seeded data file. It deletes the `nginx/` folder of the former nginx proxy.
6. **App (`tasks/main.yml`):** it starts the stack as `fantasy-hockey` with `remove_orphans`, which removes the former `fantasy-hockey-nginx` container before Caddy binds port 80. It restarts the stack when a config file changed and asserts that both containers run.

The full `docker` role does not run here: it installs Docker with `state: latest`, which would report a change whenever Docker has a new release. `provision.yml` stays root-only and does not create the user.

The play sets `default_user: fantasy-hockey` as a play variable. It has no `vars_files` and does not load `ansible/vars/main.yml`, because `vars_files` outrank play variables and that file sets `default_user: root` for provisioning. Loading the vault with `include_vars` instead of `vars_files` also keeps the playbook in the ansible-lint run, whose syntax check cannot decrypt the vault. It sets `ansible_pipelining: true`: the docker tasks become the non-root user `fantasy-hockey`, and without pipelining Ansible would need ACLs on the droplet to hand its temporary files to that user.

A second run reports `changed=0`.

## DNS Check

Caddy asks Let's Encrypt for a certificate as soon as it starts, and Let's Encrypt validates the request against the address the domain resolves to. A request that cannot be validated counts against the Let's Encrypt rate limits, so the role checks the name first. "Resolves at all" is not enough: a resolver may still cache an old answer, for example the CNAME to the all-inkl web host that the `sommerfeld.app` wildcard gave before `do` was delegated. The check therefore requires the addresses to be exactly the reserved IP. A second A record fails it too, because Let's Encrypt may validate against the other address. It stops with a message that names the domain, the addresses found and the expected reserved IP:

```text
fantasy-hockey.prod.do.sommerfeld.app resolves to nothing, not to the reserved IP <reserved-ip> of prod-fantasy-hockey. ... The A record is declared in OpenTofu: first check `tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_records` from the repository root. If the record is right, wait for the cache ... and check on the droplet with `getent ahostsv4 fantasy-hockey.prod.do.sommerfeld.app`. Apply OpenTofu only if the record is wrong (docs/cloud/digital-ocean/dns-zone.md).
```

The record is declared in OpenTofu: compare `tofu -chdir=configs-cloud/digital-ocean/opentofu output dns_records` with the reserved IP, fix and apply as described in [DNS Zone](dns-zone.md) only if it is wrong, and deploy again once the name resolves (see [Check](domain.md#check)). The check resolves through the droplet's resolver, which may cache an NXDOMAIN for up to 1800 s, an old address for up to 300 s, or the wildcard CNAME from before the delegation for up to 7200 s; `ssh root@<reserved-ip> getent ahostsv4 fantasy-hockey.prod.do.sommerfeld.app` shows what it sees.

The check runs only at deploy time and only through the droplet's resolver. It does not cover certificate renewals, CAA records, AAAA records (`getent ahostsv4` sees IPv4 only, and Let's Encrypt prefers IPv6) or whether Let's Encrypt can reach ports 80 and 443.

## TLS Termination

Caddy on the droplet terminates TLS. It is the only process that holds the certificate and its private key, and the reverse proxy in front of the app: the client talks HTTPS to Caddy, and Caddy forwards the decrypted request as plain HTTP to `app:8080` on the compose network inside the droplet. The app's port is published on `127.0.0.1` only, so nothing outside the droplet reaches it without Caddy.

```kroki-plantuml
@startuml
skinparam card<<digitalocean>> {
  BorderColor #0969DA
  BorderThickness 2
}
skinparam card<<allinkl>> {
  BorderColor #BF3989
  BorderThickness 2
}
hide <<digitalocean>> stereotype
hide <<allinkl>> stereotype
skinparam defaultTextAlignment center
skinparam rectangle<<encrypted>> {
  BackgroundColor #E6F4EA
  BorderColor #2E7D32
}
skinparam rectangle<<plain>> {
  BackgroundColor #FFF4E0
  BorderColor #C77700
}

actor "Client\n(browser)" as client
rectangle "Browser HSTS preload list\nall of .app: HTTPS only" as hsts
rectangle "Let's Encrypt\n(ZeroSSL as Caddy's fallback)" as ca

card "DigitalOcean" as digitalocean <<digitalocean>> {
  rectangle "DNS zone do.sommerfeld.app (OpenTofu)\nA fantasy-hockey.prod -> reserved IP\nCAA: letsencrypt.org, sectigo.com" as dns
  rectangle "Reserved IP 129.212.195.118\npasses TCP/UDP through, no TLS" as reservedip
  node "Droplet prod-fantasy-hockey" as droplet {
    rectangle "Caddy :443 (TCP, UDP)\nTLS termination, reverse proxy\n:80 -> 308 to https://, ACME challenge" <<encrypted>> as caddy
    rectangle "App :8080\n(127.0.0.1 and compose network only)" <<plain>> as app
  }
  storage "Volume caddy/data\ncertificate, private key, ACME account" as volume
}

client ..> hsts : 1. never sends http:// to .app
client --> dns : 2. resolve the name
client --> reservedip : 3. HTTPS (TLS 1.2/1.3, HTTP/3)
reservedip --> caddy : 4. still encrypted
caddy --> app : 5. plain HTTP\ninside the droplet
caddy <--> ca : ACME: order and renew\n(HTTP-01 on :80, TLS-ALPN-01 on :443)
ca ..> dns : checks CAA and that the name\nresolves to the reserved IP
caddy --> volume : stores
@enduml
```

| Part                        | Role in TLS                                                                                                                                                                                                                                                        |
|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Caddy                       | Orders and renews the certificate through ACME (Let's Encrypt, ZeroSSL as fallback), terminates TLS on 443, redirects `http://` on the domain to `https://` with `308`, and proxies to the app. The only place that encrypts and decrypts                          |
| App                         | Speaks plain HTTP on 8080. Never sees TLS and never faces the internet                                                                                                                                                                                             |
| `.app` HSTS preload         | Every major browser ships `.app` on its HSTS preload list, so it never sends plain HTTP to the domain, not even the first request. It encrypts nothing itself: without Caddy's certificate the browser shows an error, and clients such as `curl` ignore the list  |
| DigitalOcean DNS (OpenTofu) | Not part of the encryption, but issuance depends on it: the A record must point at the reserved IP so the ACME challenges reach Caddy, and the CAA records allow only Let's Encrypt and ZeroSSL (`sectigo.com`) to issue (see [DNS Zone](dns-zone.md#ttl-and-caa)) |
| Reserved IP                 | Forwards TCP and UDP to the droplet unchanged. No load balancer and no TLS at DigitalOcean                                                                                                                                                                         |
| Volume                      | Keeps `caddy/data` with the certificate and the private key, so a replacement droplet reuses the certificate (see [Certificates](#certificates))                                                                                                                   |

## Certificates

Caddy keeps the certificate, its private key and the ACME account in `caddy/data/` on the volume, so a replacement droplet reuses the certificate and orders no new one (see [Replacement](replacement.md)). Caddy renews the certificate itself about 30 days before it expires; the renewal needs ports 80 and 443 open, which they are (no DigitalOcean firewall). A firewall added later must allow, besides SSH (22/tcp) for Ansible, 80/tcp and 443/tcp for the ACME challenges and renewals, and 443/udp for HTTP/3. There is no ACME email address: Let's Encrypt no longer sends expiry mails. Check the certificate from outside with:

```bash
curl -sv https://fantasy-hockey.prod.do.sommerfeld.app -o /dev/null 2>&1 | grep -E 'issuer|expire'
```

A Caddyfile change, such as the log masking of Story 5.3, restarts the whole stack once on the next deploy, a short outage of the app.

In Grafana Cloud, the Proxy row of the droplet dashboard shows the days until the certificate expires (Certificate Expires In) and Caddy's certificate lines (Certificate Events), see [Certificate Status](monitoring.md#certificate-status).

## Boot Order

At boot, `docker.service` waits for the volume mount:

- **Volume attached:** the mount unit is active before Docker starts, so the app and cAdvisor come back with `data/` on the volume.
- **Volume late:** Docker waits until the device appears and the volume is mounted, but only up to systemd's default device timeout of 90 seconds (the `fstab` entry sets no `x-systemd.device-timeout=`). A volume that comes later is handled like a missing one.
- **Volume missing:** the mount fails after the device timeout, and `docker.service` fails its dependency and does not start. Nothing is written to the root disk, but the app and cAdvisor are down (`up` is `0` for both) until the volume is back. Attach it (see [Replacement](replacement.md#volume-not-attached)), then run `systemctl start docker`.

Check the order on the droplet: `systemctl show docker.service -p Requires -p After` lists the mount unit (`mnt-prod_fantasy_hockey_data.mount`) in both.

`Requires=` also works while the droplet runs: stopping or unmounting the volume's mount unit (`umount`, `systemctl stop mnt-prod_fantasy_hockey_data.mount`, a detach of the volume) stops `docker.service` too, and with it the app and cAdvisor. To remove the dependency, delete `/etc/systemd/system/docker.service.d/fantasy-hockey-volume.conf` and run `systemctl daemon-reload`; the next deploy writes it again.

## User fantasy-hockey

`fantasy-hockey` owns the deploy directory and runs `docker compose` through its `docker` group membership, so the stack does not run as root. The user has no SSH key and no password. Log in as `root` and switch to it:

```bash
ssh root@<droplet-ip>
sudo -iu fantasy-hockey
cd /mnt/prod_fantasy_hockey_data/fantasy-hockey
docker compose ps
```

## Paths and Files

The deploy directory is `fantasy_hockey_path`, `/mnt/prod_fantasy_hockey_data/fantasy-hockey` on the volume, so the data file survives a droplet replacement, see [Replacement](replacement.md).

| Path                      | Owner, mode                    | Content                                                                                                                                                                               |
|---------------------------|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `docker-compose.yml`      | `fantasy-hockey`, `0644`       | Static compose file: `app` (`sommerfeldio/fantasy-hockey`, port 8080 on `127.0.0.1` only) and `caddy` (`caddy`, ports 80, 443 and 443/udp for HTTP/3), both `restart: unless-stopped` |
| `caddy/Caddyfile`         | `fantasy-hockey`, `0644`       | Templated: serves only `fantasy_hockey_domain`, proxies to the app and answers `/metrics` with 404; every other name on port 80 gets 404                                              |
| `caddy/data/`             | `fantasy-hockey`, `0700`       | Caddy's `/data`: certificate, private key and ACME account                                                                                                                            |
| `caddy/config/`           | `fantasy-hockey`, `0700`       | Caddy's `/config`: its autosaved config                                                                                                                                               |
| `.env`                    | `fantasy-hockey`, `0600`       | Project name, session secret and Gmail API settings from the vault, read by `docker compose`                                                                                          |
| `data/`                   | UID 1000, `0755`               | Mounted into the app container at `/data`. UID 1000 is the image's non-root user                                                                                                      |
| `data/fantasy-hockey.yml` | UID 1000, `0644` (when seeded) | The app's data file: players, prediction sets, teams, predictions                                                                                                                     |

The Caddy container runs as root, so it writes to `caddy/data/` and `caddy/config/` despite their owner. When `docker-compose.yml`, `caddy/Caddyfile` or `.env` changes, the role replaces the file and restarts the stack. The image is pulled only when it is missing (`pull: missing`), so a new image version comes from a change to `docker-compose.yml`.

Alloy (installed by `provision.yml`) scrapes the app at `localhost:8080/metrics` (job `fantasy-hockey`), which the compose file binds to the loopback interface. From outside, Caddy answers `/metrics` (any case, with extra slashes) with 404 without forwarding it.

## Seed Rule

`data/fantasy-hockey.yml` is seeded from the role template `fantasy-hockey.yml.j2` only when it does not exist. The players come from the vault, the season and the before-season deadline from the role defaults. Once the file exists, the deploy never touches it again, not its content, owner or mode. The app rewrites the file at runtime and the pool operator edits it by hand, so a deploy must never overwrite live pool data. To start over from the template, delete the file and deploy again.

## Secrets

The secrets are in the Ansible Vault file `configs-cloud/digital-ocean/ansible/vars/fantasy-hockey-vault.yml`: `fantasy_hockey_session_secret`, `fantasy_hockey_gmail_client_id`, `fantasy_hockey_gmail_client_secret`, `fantasy_hockey_gmail_refresh_token`, `fantasy_hockey_gmail_sender` and `fantasy_hockey_players`. Edit them with:

```bash
task cloud:digital-ocean:ansible:vault:fantasy-hockey
```

The plain variables (`fantasy_hockey_volume_mount`, `fantasy_hockey_path`, `fantasy_hockey_domain`, `fantasy_hockey_season`, `fantasy_hockey_regular_season_deadline_utc`, `fantasy_hockey_ps1`) are role defaults in `ansible/roles/fantasy-hockey/defaults/main.yml`.

## Tasks

```bash
task cloud:digital-ocean:ansible:deploy-fantasy-hockey   # run deploy-fantasy-hockey.yml
task cloud:digital-ocean:ansible:vault:fantasy-hockey    # edit the fantasy hockey secrets
task cloud:deploy:all                                    # opentofu:apply, then ansible:all (provision and app deploy)
```

The deploy asks for the vault password and stops early when `DIGITALOCEAN_ACCESS_TOKEN` is not set. `deploy:all` asks for the vault password only once, because provisioning and the app deploy run in one Ansible run (`playbooks/all.yml`).

## Checks

After a deploy:

- `https://fantasy-hockey.prod.do.sommerfeld.app` opens the app in a browser outside the home network, with a valid Let's Encrypt certificate. `curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://fantasy-hockey.prod.do.sommerfeld.app` prints `302 https://fantasy-hockey.prod.do.sommerfeld.app/login` (the app sends `/` to its login page), and `curl -s -o /dev/null -w '%{http_code}\n' https://fantasy-hockey.prod.do.sommerfeld.app/login` prints `200`.
- `curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' 'http://fantasy-hockey.prod.do.sommerfeld.app/x?y=1'` prints `308 https://fantasy-hockey.prod.do.sommerfeld.app/x?y=1`.
- `curl -s -o /dev/null -w '%{http_code}\n' https://fantasy-hockey.prod.do.sommerfeld.app/metrics` prints `404`.
- `curl -s -o /dev/null -w '%{http_code}\n' http://<reserved-ip>/` prints `404`, and `curl https://<reserved-ip>/` fails the TLS handshake.
- `docker compose ps` as `fantasy-hockey` in the deploy directory lists `fantasy-hockey-app` and `fantasy-hockey-caddy`, and `ls` shows no `nginx/` folder.
- In Grafana Cloud (Explore), `up{job="fantasy-hockey", environment="digital-ocean", stage="prod"}` is `1`.

## Pi Retirement

The app ran on `pi4-0002` behind a port forward of the home router until the droplet took over. The role moved from `configs-homelab/ansible/roles` to `configs-cloud/digital-ocean/ansible/roles/fantasy-hockey`, and the pi4-0002 play in `configs-homelab/ansible/playbooks/raspi.yml` became a cleanup play. Run it only after the app is verified on the droplet, then remove the port forward in the router.

The cleanup play is tagged `never` and `fantasy-hockey-cleanup`, so `task homelab:ansible:raspi` and `task homelab:ansible:all` (`all.yml` imports `raspi.yml`) skip it. Only its own task runs it, limited to `pi4-0002`, so the other Pis are not contacted (their plays would still gather facts, and an unreachable Pi would fail the run):

```bash
task homelab:ansible:raspi:fantasy-hockey-cleanup
```

The cleanup play targets only `pi4-0002`:

1. It lists the running containers and fails, before removing anything, when a container runs that is neither part of the `fantasy-hockey` project (names starting with `fantasy-hockey-`) nor a fleet container. Fleet containers are the ones the homelab roles run on every Pi, listed in the play variable `fantasy_hockey_pi_fleet_containers`; today that is `cadvisor` from the `grafana-cloud/exporters` role. The failure lists the other containers.
2. When `/opt/fantasy-hockey` exists, it stops and removes the stack with `docker compose down` (`docker_compose_v2`, `state: absent`) and deletes `/opt/fantasy-hockey`.

The Pi's data is deleted without a backup; it is not migrated to the droplet. A second run finds no `/opt/fantasy-hockey` and reports `changed=0`.
