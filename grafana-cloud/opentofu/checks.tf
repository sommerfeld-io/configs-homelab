locals {
  # One entry per website. The key is the site name and becomes the "site"
  # label of the check.
  #
  # Options (all required):
  #   job                        Job label of the check, groups checks in Grafana,
  #                              e.g. "up-and-running___websites".
  #   target                     URL the probes request, e.g. "https://www.example.com".
  #   probes                     List of probe locations the check runs from, from
  #                              probes.tf, e.g. [local.probe_location_frankfurt].
  #   http_duration_threshold_ms Number (ms). The HTTPRequestDurationTooHighAvg
  #                              alert fires when the average request duration
  #                              over one hour is above this value.
  #
  # Options (optional):
  #   tls_expiry_threshold_days  Number (days). The TLSTargetCertificateCloseToExpiring
  #                              alert fires when the certificate expires within
  #                              this many days. Defaults to 5.
  checks = {
    "www.fb-brunnenbau.de" = {
      job                        = "up-and-running___websites"
      probes                     = [local.probe_location_frankfurt, local.probe_location_paris]
      target                     = "https://www.fb-brunnenbau.de"
      http_duration_threshold_ms = 1200
    }
    "www.minifigs.de" = {
      job                        = "up-and-running___websites"
      probes                     = [local.probe_location_frankfurt, local.probe_location_paris]
      target                     = "https://www.minifigs.de"
      http_duration_threshold_ms = 2000
    }
    # The fantasy hockey app on the DigitalOcean droplet (configs-cloud).
    # Caddy renews its Let's Encrypt certificate when a third of its lifetime
    # is left (about 30 days), so 14 days left means renewal keeps failing.
    "fantasy-hockey.prod.do.sommerfeld.app" = {
      job                        = "up-and-running___digital-ocean"
      probes                     = [local.probe_location_frankfurt, local.probe_location_paris]
      target                     = "https://fantasy-hockey.prod.do.sommerfeld.app"
      http_duration_threshold_ms = 300
      tls_expiry_threshold_days  = 14
    }
  }

  # Settings shared by every check.
  frequency_ms = 600000 # 10 minutes
  timeout_ms   = 10000  # 10 seconds
}

resource "grafana_synthetic_monitoring_check" "this" {
  for_each = local.checks

  job       = each.value.job
  target    = each.value.target
  enabled   = true
  probes    = each.value.probes
  labels    = { site = each.key }
  frequency = local.frequency_ms
  timeout   = local.timeout_ms

  settings {
    http {
      method              = "GET"
      fail_if_not_ssl     = true
      fail_if_ssl         = false
      ip_version          = "V4"
      no_follow_redirects = false
    }
  }
}

resource "grafana_synthetic_monitoring_check_alerts" "this" {
  for_each = local.checks

  check_id = grafana_synthetic_monitoring_check.this[each.key].id
  alerts = [
    {
      name        = "ProbeFailedExecutionsTooHigh"
      threshold   = 2
      period      = "30m"
      runbook_url = ""
    },
    {
      # Threshold in days before the certificate expires. Has no period.
      name        = "TLSTargetCertificateCloseToExpiring"
      threshold   = try(each.value.tls_expiry_threshold_days, 5)
      period      = ""
      runbook_url = ""
    },
    {
      name        = "HTTPRequestDurationTooHighAvg"
      threshold   = each.value.http_duration_threshold_ms
      period      = "1h"
      runbook_url = ""
    },
  ]
}
