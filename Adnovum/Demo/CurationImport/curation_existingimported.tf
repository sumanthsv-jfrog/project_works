# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "1016"
resource "xray_curation_policy" "jk_project_curation_malicious_block" {
  condition_id          = "1"
  decision_owners       = ["sec-group"]
  label_waivers         = null
  name                  = "jk-project-curation-malicious-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "3"
resource "xray_curation_policy" "WORKSAFE_CURATION_IMMATURE_BLOCK" {
  condition_id          = "14"
  decision_owners       = ["worksafeperm-security-group"]
  label_waivers         = null
  name                  = "WORKSAFE-CURATION_IMMATURE_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1115"
resource "xray_curation_policy" "sum_dev_block_malicious" {
  condition_id          = "1"
  decision_owners       = null
  label_waivers         = null
  name                  = "sum-dev-block-malicious"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "1017"
resource "xray_curation_policy" "jk_project_curation_no_dockerhub_block" {
  condition_id          = "17"
  decision_owners       = ["sec-group"]
  label_waivers         = null
  name                  = "jk-project-curation-no-dockerhub-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "10"
resource "xray_curation_policy" "projectkey_critical_block" {
  condition_id    = "1"
  decision_owners = ["armor-reader"]
  label_waivers = [
    {
      justification = "allowing"
      label         = "projkey-waiver-label"
    },
  ]
  name                  = "projectkey-critical-block"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = ["bmc-docker-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1011"
resource "xray_curation_policy" "alpha_npm_security_gate" {
  condition_id          = "1021"
  decision_owners       = null
  label_waivers         = null
  name                  = "alpha-npm-security-gate"
  notify_emails         = ["srikanthp@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["alpha-npm-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "1020"
resource "xray_curation_policy" "anilkt_npm_curation_policy" {
  condition_id          = "5"
  decision_owners       = ["ics-admin-group"]
  label_waivers         = null
  name                  = "anilkt-npm-curation-policy"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["anilkt-npm-curation-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1116"
resource "xray_curation_policy" "sum_dev_high_severity_all_repos" {
  condition_id          = "4"
  decision_owners       = ["sum-dev-developers"]
  label_waivers         = null
  name                  = "sum-dev-high-severity-all-repos"
  notify_emails         = ["alice@example.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1012"
resource "xray_curation_policy" "jk_project_curation_critical_block" {
  condition_id          = "3"
  decision_owners       = ["sec-group"]
  label_waivers         = null
  name                  = "jk-project-curation-critical-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1112"
resource "xray_curation_policy" "sum_adnovum_malicious_severity_block" {
  condition_id          = "1"
  decision_owners       = null
  label_waivers         = null
  name                  = "sum_adnovum_malicious_severity_block"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "1013"
resource "xray_curation_policy" "jk_project_curation_aged_block" {
  condition_id    = "13"
  decision_owners = ["sec-group"]
  label_waivers = [
    {
      justification = "waiver-nopt 9.0.0 and npmcli/prmoise-spawn 9.0.1"
      label         = "jk-project-waiver-label"
    },
  ]
  name                  = "jk-project-curation-aged-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "20"
resource "xray_custom_curation_condition" "testcondition" {
  condition_template_id = "BannedLabels"
  name                  = "testcondition"
  param_values = jsonencode([{
    param_id = "list_of_labels"
    value    = ["WORKSAFE_BANNED"]
  }])
}

# __generated__ by Terraform from "1021"
resource "xray_curation_policy" "anilkt_npm_malicious_policy" {
  condition_id          = "1"
  decision_owners       = null
  label_waivers         = null
  name                  = "anilkt-npm-malicious-policy"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["anilkt-npm-curation-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "8"
resource "xray_curation_policy" "testpolicy_worksafe" {
  condition_id          = "20"
  decision_owners       = null
  label_waivers         = null
  name                  = "testpolicy_worksafe"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "19"
resource "xray_custom_curation_condition" "WORKSAFE_BANNED_LABEL" {
  condition_template_id = "BannedLabels"
  name                  = "WORKSAFE_BANNED_LABEL"
  param_values = jsonencode([{
    param_id = "list_of_labels"
    value    = ["WORKSAFE_BANNED"]
  }])
}

# __generated__ by Terraform from "1121"
resource "xray_curation_policy" "sum_dev_high_cvss_block" {
  condition_id          = "1047"
  decision_owners       = ["sum-dev-developers"]
  label_waivers         = null
  name                  = "sum-dev-high-cvss-block"
  notify_emails         = ["alice@example.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["sum-dev-maven-remote", "sum-dev-npm-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1113"
resource "xray_curation_policy" "sum_adnovum_multi_ecosystem_audit_policy" {
  condition_id          = "3"
  decision_owners       = null
  label_waivers         = null
  name                  = "sum_adnovum_multi-ecosystem-audit-policy"
  notify_emails         = ["anilkt@jfrog.com", "sumanthsv@jfrog.com"]
  pkg_types_include     = ["npm"]
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "pkg_types"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "1"
resource "xray_curation_policy" "WORKSAFE_CURATION_MALICIOUS_BLOCK" {
  condition_id          = "1"
  decision_owners       = null
  label_waivers         = null
  name                  = "WORKSAFE-CURATION_MALICIOUS_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "1114"
resource "xray_curation_policy" "sum_adnovum_high_severity_manual_review" {
  condition_id    = "4"
  decision_owners = ["terraform_curation_admin_group"]
  label_waivers = [
    {
      justification = "Pre-approved by security team for enterprise use"
      label         = "jk-project-banned-label"
    },
  ]
  name                  = "sum_adnovum_high-severity-manual-review"
  notify_emails         = ["anilkt@jfrog.com", "sumanthsv@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers = [
    {
      all_versions  = false
      justification = "Patched version - security team approved"
      pkg_name      = "lodash"
      pkg_type      = "npm"
      pkg_versions  = ["4.18.1"]
    },
  ]
}

# __generated__ by Terraform from "1015"
resource "xray_curation_policy" "jk_project_curation_immature_block" {
  condition_id          = "14"
  decision_owners       = ["sec-group"]
  label_waivers         = null
  name                  = "jk-project-curation-immature-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "4"
resource "xray_curation_policy" "WORKSAFE_CURATION_AGED_BLOCK" {
  condition_id          = "12"
  decision_owners       = ["worksafeperm-security-group"]
  label_waivers         = null
  name                  = "WORKSAFE_CURATION_AGED_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1101"
resource "xray_curation_policy" "Ubank_Curation_Aged_Block" {
  condition_id          = "12"
  decision_owners       = ["alpha-ps-admins", "bmcgroup1"]
  label_waivers         = null
  name                  = "Ubank_Curation_Aged_Block"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["ubank-docker-remote", "ubank-npm-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1021"
resource "xray_custom_curation_condition" "alpha_high_critical_cve" {
  condition_template_id = "CVECVSSRange"
  name                  = "alpha-high-critical-cve"
  param_values = jsonencode([{
    param_id = "vulnerability_cvss_score_range"
    value    = [0, 7]
    }, {
    param_id = "apply_only_if_fix_is_available"
    value    = true
    }, {
    param_id = "do_not_apply_for_already_existing_vulnerabilities"
    value    = true
  }])
}

# __generated__ by Terraform from "1120"
resource "xray_curation_policy" "sum_dev_docker_curation" {
  condition_id          = "17"
  decision_owners       = ["sum-dev-developers"]
  label_waivers         = null
  name                  = "sum-dev-docker-curation"
  notify_emails         = ["alice@example.com"]
  pkg_types_include     = ["docker"]
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "pkg_types"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "7"
resource "xray_curation_policy" "WORKSAFE_CURATION_BLOCKED_LABEL_BLOCK" {
  condition_id          = "19"
  decision_owners       = null
  label_waivers         = null
  name                  = "WORKSAFE_CURATION_BLOCKED_LABEL_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "5"
resource "xray_curation_policy" "WORKSAFE_CURATION_NO_LIC_BLOCK" {
  condition_id    = "8"
  decision_owners = ["worksafeperm-security-group"]
  label_waivers = [
    {
      justification = "test"
      label         = "worksafe_new_label"
    },
  ]
  name                  = "WORKSAFE_CURATION_NO_LIC_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1032"
resource "xray_curation_policy" "testcuration" {
  condition_id          = "5"
  decision_owners       = ["terraform_curation_admin_group"]
  label_waivers         = null
  name                  = "testcuration"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["testcuration"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1040"
resource "xray_curation_policy" "example_forbidden_policy" {
  condition_id          = "1"
  decision_owners       = null
  label_waivers         = null
  name                  = "example-forbidden-policy"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "forbidden"
  waivers               = null
}

# __generated__ by Terraform from "1031"
resource "xray_custom_curation_condition" "sum_adnovum_high_severity_vulnerabilities" {
  condition_template_id = "CVECVSSRange"
  name                  = "sum-adnovum_high-severity-vulnerabilities"
  param_values = jsonencode([{
    param_id = "vulnerability_cvss_score_range"
    value    = [7, 10]
    }, {
    param_id = "apply_only_if_fix_is_available"
    value    = true
    }, {
    param_id = "do_not_apply_for_already_existing_vulnerabilities"
    value    = false
    }, {
    param_id = "epss"
    value = {
      percentile = 90
    }
  }])
}

# __generated__ by Terraform from "1019"
resource "xray_curation_policy" "jk_project_curation_blocked_label_block" {
  condition_id    = "1022"
  decision_owners = null
  label_waivers = [
    {
      justification = "added auto waiver approval"
      label         = "jk-project-auto-wavier-label"
    },
  ]
  name                  = "jk-project-curation-blocked-label-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "auto_approved"
  waivers               = null
}

# __generated__ by Terraform from "2"
resource "xray_curation_policy" "WORKSAFE_CURATION_CRITICAL_BLOCK" {
  condition_id          = "3"
  decision_owners       = ["worksafeperm-security-group"]
  label_waivers         = null
  name                  = "WORKSAFE_CURATION_CRITICAL_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1047"
resource "xray_custom_curation_condition" "sum_dev_high_cvss" {
  condition_template_id = "CVECVSSRange"
  name                  = "sum-dev-high-cvss"
  param_values = jsonencode([{
    param_id = "vulnerability_cvss_score_range"
    value    = [7, 10]
    }, {
    param_id = "apply_only_if_fix_is_available"
    value    = true
    }, {
    param_id = "do_not_apply_for_already_existing_vulnerabilities"
    value    = false
  }])
}

# __generated__ by Terraform from "1122"
resource "xray_curation_policy" "sum_dev_remote_audit" {
  condition_id          = "3"
  decision_owners       = null
  label_waivers         = null
  name                  = "sum-dev-remote-audit"
  notify_emails         = ["alice@example.com"]
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = ["sum-dev-maven-remote", "sum-dev-npm-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "auto_approved"
  waivers               = null
}

# __generated__ by Terraform from "6"
resource "xray_curation_policy" "WORKSAFE_CURATION_NO_DOCKERHUB_BLOCK" {
  condition_id          = "17"
  decision_owners       = ["worksafeperm-security-group"]
  label_waivers         = null
  name                  = "WORKSAFE_CURATION_NO_DOCKERHUB_BLOCK"
  notify_emails         = null
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1022"
resource "xray_custom_curation_condition" "jk_project_package_banned" {
  condition_template_id = "BannedLabels"
  name                  = "jk-project-package-banned"
  param_values = jsonencode([{
    param_id = "list_of_labels"
    value    = ["jk-project-banned-label"]
  }])
}

# __generated__ by Terraform from "1035"
resource "xray_curation_policy" "psinfra_block_high_risk_packages" {
  condition_id          = "2"
  decision_owners       = ["psinfra-security-admins"]
  label_waivers         = null
  name                  = "psinfra-block-high-risk-packages"
  notify_emails         = ["nagag@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "dry_run"
  repo_exclude          = null
  repo_include          = null
  scope                 = "all_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "1018"
resource "xray_curation_policy" "jk_project_curation_no_lic_block" {
  condition_id          = "8"
  decision_owners       = ["sec-group"]
  label_waivers         = null
  name                  = "jk-project-curation-no-lic-block"
  notify_emails         = ["jeffreyyk@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["jk-project-docker-dev-remote", "jk-project-npmjs-dev-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}

# __generated__ by Terraform from "9"
resource "xray_curation_policy" "nagag_docker_hub" {
  condition_id          = "7"
  decision_owners       = ["alpha-ps-devs"]
  label_waivers         = null
  name                  = "nagag-docker-hub"
  notify_emails         = ["nagag@jfrog.com"]
  pkg_types_include     = null
  policy_action         = "block"
  repo_exclude          = null
  repo_include          = ["nd-docker-remote", "ubank-docker-remote"]
  scope                 = "specific_repos"
  waiver_request_config = "manual"
  waivers               = null
}
