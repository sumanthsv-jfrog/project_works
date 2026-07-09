# Curation Policy - Malicious policy with block
resource "xray_curation_policy" "ubank_malicious_severity_block" {
  name                  = "sum_ubank_malicious_severity"
  condition_id          = "1"
  scope                 = "all_repos"
  policy_action         = "block"
  waiver_request_config = "forbidden"
}

# Curation Policy - Critical Severity Vulnerabilities with fix version available and with Manual Review
resource "xray_curation_policy" "ubank_critical_severity_manual" {
  name                  = "sum_ubank_critical-severity-manual-review_withfix"
  condition_id          = "2"
  scope                 = "all_repos"
  policy_action         = "dry_run"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Critical Severity Vulnerabilities with no fix available and with Manual Review
resource "xray_curation_policy" "ubank_critical_severity_manual_nofix" {
  name                  = "sum_ubank_critical-severity-manual-review_nofix"
  condition_id          = "3"
  scope                 = "all_repos"
  policy_action         = "dry_run"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - High Severity Vulnerabilities with Manual Review
resource "xray_curation_policy" "ubank_high_severity_manual" {
  name                  = "sum_ubank_high-severity-manual-review"
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



# Curation Policy - Package has no identified License
resource "xray_curation_policy" "ubank_nolicense_restrictions" {
  name                  = "sum_ubank_nolicense-compliance-policy"
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

# Curation Policy - Immature Packages (< 2 days old) (Dry Run)
resource "xray_curation_policy" "ubank_immature_dry_run_permissive" {
  name                  = "sum_ubank_immature-permissive"
  condition_id          = "14"
  scope                 = "all_repos"
  policy_action         = "dry_run"  
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Immature Packages (< 30 days old) (Dry Run)
resource "xray_curation_policy" "ubank_immature_dry_run_strict" {
  name                  = "sum_ubank_immature-srtict"
  condition_id          = "16"
  scope                 = "all_repos"
  policy_action         = "dry_run"  
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}


# Curation Policy - Aged(2 years old) and no newer version available Package Audit (Dry Run)
resource "xray_curation_policy" "ubank_aged_dry_run" {
  name                  = "sum_ubank_aged-audit-policy"
  condition_id          = "12"
  scope                 = "all_repos"
  policy_action         = "dry_run"  
  waiver_request_config = "forbidden"
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

# Curation Policy - Non-Official DockerHub Images dry_run
resource "xray_curation_policy" "ubank_nodockerhub_official_dry_run" {
  name                  = "sum_ubank_nodockerhub_official_dry_run"
  condition_id          = "17"
  scope                 = "pkg_types"
  pkg_types_include     = ["docker"]
  policy_action         = "dry_run"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]
  notify_emails         = ["sumanthsv@jfrog.com", "anilkt@jfrog.com"]
}

resource "xray_curation_policy" "sum_ubank_production_strict" {
  name                  = "sum_ubnak_production-strict-policy"
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