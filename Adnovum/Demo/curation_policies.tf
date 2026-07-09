# Curation Policy - Malicious policy with block
resource "xray_curation_policy" "adnovum_malicious_severity_block" {
  name                  = "sum_adnovum_malicious_severity_block"
  condition_id          = "1"
  scope                 = "all_repos"
  policy_action         = "dry_run"
  waiver_request_config = "forbidden"
}

resource "xray_curation_policy" "adnovum_multi_ecosystem_dry_run" {
  name                  = "sum_adnovum_multi-ecosystem-audit-policy"
  condition_id          = "3"
  scope                 = "pkg_types"
  pkg_types_include     = ["npm"]
  policy_action         = "dry_run"   # Test mode - logs violations without blocking
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

resource "xray_curation_policy" "adnovum_high_severity_manual" {
  name                  = "sum_adnovum_high-severity-manual-review"
  condition_id          = "4"
  scope                 = "all_repos"
  policy_action         = "dry_run"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]

  # Pre-approved waivers for known safe packages
  waivers = [
    {
      pkg_type      = "npm"
      pkg_name      = "lodash"
      all_versions  = false
      pkg_versions  = ["4.18.1"]
      justification = "Patched version - security team approved"
    }
  ]

  label_waivers = [
    {
      label         = "jk-project-banned-label"
      justification = "Pre-approved by security team for enterprise use"
    }
  ]
}
