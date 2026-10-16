output "check_ids" {
  description = "ID of each Synthetic Monitoring check, keyed by site"
  value       = { for site, check in grafana_synthetic_monitoring_check.this : site => check.id }
}
