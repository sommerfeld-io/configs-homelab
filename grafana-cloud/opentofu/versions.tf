terraform {
  required_version = "1.12.7"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.50.0"
    }
  }
}

# Only Synthetic Monitoring resources live here, so the provider needs no
# Grafana instance URL or service account token. It reads the Synthetic
# Monitoring access token from GRAFANA_SM_ACCESS_TOKEN.
provider "grafana" {
  sm_url = "https://synthetic-monitoring-api-eu-west-2.grafana.net"
}
