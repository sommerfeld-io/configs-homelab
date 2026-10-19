# The public probe locations of Grafana Cloud, looked up by name, so no probe
# ID is hard-coded. The data source maps each probe name to its ID.
data "grafana_synthetic_monitoring_probes" "this" {}

locals {
  probe_location_frankfurt = data.grafana_synthetic_monitoring_probes.this.probes["Frankfurt"]
  probe_location_paris     = data.grafana_synthetic_monitoring_probes.this.probes["Paris"]
}
