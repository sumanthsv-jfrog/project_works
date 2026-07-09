# Custom Curation Condition - High Severity Vulnerabilities
# Condition ID will be used in curation policies
resource "xray_custom_curation_condition" "adnovum_high_severity_vulns" {
  name                  = "sum-adnovum_high-severity-vulnerabilities"
  condition_template_id = "CVECVSSRange"

  param_values = jsonencode([
    {
      param_id = "vulnerability_cvss_score_range"
      value    = [7.0, 10.0]
    },
    {
      param_id = "apply_only_if_fix_is_available"
      value    = true
    },
    {
      param_id = "do_not_apply_for_already_existing_vulnerabilities"
      value    = false
    },
    {
      param_id = "epss"
      value = {
        percentile = 90.0
      }
    }
  ])
}

# Custom Curation Condition - License Compliance
resource "xray_custom_curation_condition" "adnovum_license_compliance" {
  name                  = "adnovum_license-compliance"
  condition_template_id = "BannedLicenses"

  param_values = jsonencode([
    {
      param_id = "list_of_package_licenses"
      value    = ["GPL-3.0"]
    },
    {
      param_id = "multiple_license_permissive_approach"
      value    = false
    }
  ])
}

# Custom Curation Condition - Unmaintained Packages
resource "xray_custom_curation_condition" "adnovum_unmaintained_packages" {
  name                  = "adnovum_unmaintained-packages"
  condition_template_id = "OpenSSF"

  param_values = jsonencode([
    {
      param_id = "list_of_scorecard_checks"
      value = {
        maintained = 5
      }
    },
    {
      param_id = "block_in_case_check_value_is_missing"
      value    = true
    }
  ])
}

# Custom Curation Condition - Known Vulnerable Packages
resource "xray_custom_curation_condition" "adnovum_known_vulnerabilities" {
  name                  = "adnovum_known-vulnerabilities"
  condition_template_id = "SpecificVersions"

  param_values = jsonencode([
    {
      param_id = "package_type"
      value    = "Maven"
    },
    {
      param_id = "package_name"
      value    = "com.gitee.Jmysy:binlog4j-core"
    },
    {
      param_id = "package_versions"
      value = {
        equals = ["1.9.1"]
      }
    }
  ])
}
