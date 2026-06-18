# Curation Policy - High Severity Vulnerabilities with Manual Review
resource "xray_curation_policy" "adnovum_high_severity_manual" {
  name                  = "adnovum_high-severity-manual-review"
  condition_id          = "3"
  scope                 = "all_repos"
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]

  notify_emails = ["anilkt@jfrog.com"]

  # Pre-approved waivers for known safe packages
  waivers = [
    {
      pkg_type      = "npm"
      pkg_name      = "lodash"
      all_versions  = false
      pkg_versions  = ["4.18.1"]
      justification = "Patched version - security team approved"
    }
    # {
    #   pkg_type      = "npm"
    #   pkg_name      = "express"
    #   all_versions  = false
    #   pkg_versions  = ["4.18.2", "4.18.1"]
    #   justification = "LTS versions - comprehensive security review completed"
    # },
    # {
    #   pkg_type      = "Maven"
    #   pkg_name      = "log4j-core"
    #   all_versions  = false
    #   pkg_versions  = ["2.17.1", "2.18.0", "2.19.0"]
    #   justification = "Post-CVE-2021-44228 versions - fully patched"
    # }
  ]

  label_waivers = [
    {
      label         = "jk-project-banned-label"
      justification = "Pre-approved by security team for enterprise use"
    }
  ]
}

# Curation Policy - Production Repositories Only
resource "xray_curation_policy" "adnovum_production_strict" {
  name                  = "adnovum_production-strict-policy"
  condition_id          = "3"
  scope                 = "specific_repos"
  repo_include          = ["alpha-npm-remote"]
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]

  notify_emails = ["prod-security@company.com", "release-team@company.com"]

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
  name                  = "adnovum_dev-auto-approved-policy"
  condition_id          = "3"
  scope                 = "all_repos"
  repo_exclude          = ["alpha-npm-remote"]
  policy_action         = "dry_run" # Only logs violations, doesn't block
  waiver_request_config = "auto_approved"

  notify_emails = ["dev-team@company.com"]

  waivers = [
    {
      pkg_type      = "PyPI"
      pkg_name      = "Django"
      all_versions  = true
      justification = "Development framework - auto-approved for dev environments"
    }
  ]
}

# Curation Policy - License Compliance
resource "xray_curation_policy" "adnovum_license_restrictions" {
  name                  = "adnovum_license-compliance-policy"
  condition_id          = "3"
  scope                 = "pkg_types"
  pkg_types_include     = ["npm"]
  policy_action         = "block"
  waiver_request_config = "manual"
  decision_owners       = ["terraform_curation_admin_group"]

  notify_emails = ["anilkt@jfrog.com"]

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

# Curation Policy - Comprehensive Multi-Ecosystem with Dry-Run
resource "xray_curation_policy" "adnovum_multi_ecosystem_dry_run" {
  name                  = "adnovum_multi-ecosystem-audit-policy"
  condition_id          = "3"
  scope                 = "pkg_types"
  pkg_types_include     = ["npm"]
  policy_action         = "dry_run" # Test mode - logs violations without blocking
  waiver_request_config = "forbidden"

  notify_emails = ["anilkt@jfrog.com"]

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

# Curation Policy - Specific Packages Blacklist
resource "xray_curation_policy" "adnovum_vulnerable_packages_block" {
  name                  = "adnovum_vulnerable-packages-blacklist"
  condition_id          = "3"
  scope                 = "all_repos"
  policy_action         = "block" # Hard block - no waivers
  waiver_request_config = "forbidden"

  notify_emails = ["anilkt@jfrog.com"]

  # No waivers section - these packages cannot be used at all
  # Uncomment if you want to forbid entire packages:
  # waivers = [
  #   {
  #     pkg_type      = "npm"
  #     pkg_name      = "unsafe-package"
  #     all_versions  = true
  #     justification = "Package has critical vulnerability with no patch"
  #   }
  # ]
}
