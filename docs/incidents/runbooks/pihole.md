# Runbook - Pi-hole

Pi-hole runs as a Docker Compose service on `pi4-dradis.fritz.box`, deployed by the [RasPi / Pi-hole](../../ansible/roles/raspi/pihole.md) Ansible role. Use this runbook when Pi-hole is not resolving DNS queries or the container is otherwise not up and running.

## Todo

- [ ] SSH into `pi4-dradis.fritz.box`
- [ ] `cd /opt/pihole`
- [ ] Inspect the container state with `docker ps`
- [ ] Inspect recent logs with `docker compose logs`
- [ ] Stop the stack with `docker compose down`
- [ ] Start the stack with `docker compose up -d`
- [ ] Confirm Pi-hole is resolving DNS queries again

## Alternative: metrics and logs in Grafana

Metrics and logs can also be inspected without SSH access, via Grafana Cloud:

- [Pi-hole overview dashboard](https://sommerfeldio.grafana.net/d/services-pihole-overview/services-pi-hole-overview?from=now-6h&to=now&timezone=browser)
- Explore, with datasource `grafanacloud-sommerfeldio-logs` and query:

```logql
{service_name="pihole"}
```

## Alternative: re-run the Ansible role

Instead of manually restarting the container on the node, re-apply the [`raspi` playbook](../../ansible/playbooks/raspi.md) from this repo, which re-deploys the compose file and (re-)starts the stack:

```bash
task ansible:raspi
```
