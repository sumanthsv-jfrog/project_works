# Curation Policy - Malicious policy with block
resource "xray_curation_policy" "adnovum_malicious_severity_block" {
  name                  = "sum_adnovum_malicious_severity_block"
  condition_id          = "1"
  scope                 = "all_repos"
  policy_action         = "block"
  waiver_request_config = "forbidden"
}

# Curation Policy - Critical Severity Vulnerabilities with fix version available and with Manual Review
resource "xray_curation_policy" "adnovum_critical_severity_manual" {
  name                  = "sum_adnovum_critical-severity-manual-review"
  condition_id          = "2"
  scope                 = "all_repos"
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Critical Severity Vulnerabilities with no fix available and with Manual Review
resource "xray_curation_policy" "adnovum_critical_severity_manual_nofix" {
  name                  = "sum_adnovum_critical-severity-manual-review_nofix"
  condition_id          = "3"
  scope                 = "all_repos"
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - High Severity Vulnerabilities with Manual Review
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

# Curation Policy - Production Repositories Only
resource "xray_curation_policy" "sum_adnovum_production_strict" {
  name                  = "sum_adnovum_production-strict-policy"
  condition_id          = "3"
  scope                 = "specific_repos"
  repo_include          = ["alpha-npm-remote"]
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["prod-security@company.com", "release-team@company.com"]

  waivers = [
    {
      pkg_type      = "npm"
      pkg_name      = "lodash"
      all_versions  = false
      pkg_versions  = ["4.18.1"]
      justification = "Patched version - security team approved"
    }
  ]
}

# Curation Policy - Auto-Approved for Development
resource "xray_curation_policy" "adnovum_dev_auto_approved" {
  name                  = "sum_adnovum_dev-auto-approved-policy"
  condition_id          = "3"
  scope                 = "all_repos"
  repo_exclude          = ["alpha-npm-remote"]
  policy_action         = "dry_run"   # Only logs violations, doesn't block
  waiver_request_config = "auto_approved"
  notify_emails         = ["dev-team@company.com"]
}

# Curation Policy - Package has no identified License
resource "xray_curation_policy" "adnovum_nolicense_restrictions" {
  name                  = "sum_adnovum_nolicense-compliance-policy"
  condition_id          = "8"
  scope                 = "all_repos"
  policy_action         = "dry_run"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]

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
      justification = "Packages with approved open source licenses"
    }
  ]
}

# Curation Policy - Immature Package Audit (Dry Run)
resource "xray_curation_policy" "adnovum_immature_dry_run" {
  name                  = "sum_adnovum_immature-audit-policy"
  condition_id          = "14"
  scope                 = "all_repos"
  policy_action         = "dry_run"   # Test mode - logs violations without blocking
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Immature Package Audit (Dry Run)
resource "xray_curation_policy" "adnovum_aged_dry_run" {
  name                  = "sum_adnovum_aged-audit-policy"
  condition_id          = "12"
  scope                 = "all_repos"
  policy_action         = "dry_run"   # Test mode - logs violations without blocking
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Multi-Ecosystem npm Audit (Dry Run)
resource "xray_curation_policy" "adnovum_multi_ecosystem_dry_run" {
  name                  = "sum_adnovum_multi-ecosystem-audit-policy"
  condition_id          = "3"
  scope                 = "pkg_types"
  pkg_types_include     = ["npm"]
  policy_action         = "dry_run"   # Test mode - logs violations without blocking
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Non-Official DockerHub Images Block
resource "xray_curation_policy" "adnovum_nodockerhub_official_block" {
  name                  = "sum_adnovum_nodockerhub_official_block"
  condition_id          = "17"
  scope                 = "pkg_types"
  pkg_types_include     = ["docker"]
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}
