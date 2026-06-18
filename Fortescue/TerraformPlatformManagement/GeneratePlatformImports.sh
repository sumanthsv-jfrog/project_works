#!/usr/bin/env bash
# =============================================================================
# generate_artifactory_imports.sh
# Generates Terraform import blocks for Artifactory/JFrog resources:
#   - Repositories       (jfrog/artifactory)
#   - Users              (jfrog/artifactory — skips system users)
#   - Groups             (jfrog/platform)
#   - Permissions        (jfrog/platform)
#   - Xray Policies      (jfrog/xray — security, license, operational_risk)
#   - Xray Watches       (jfrog/xray)
#   - Curation Conditions (jfrog/xray)
#   - Curation Policies  (jfrog/xray)
#
# Requirements: curl, jq, Terraform 1.5+
#
# Usage:
#   export ARTIFACTORY_URL="https://your-org.jfrog.io"
#   export ARTIFACTORY_TOKEN="your-access-token"
#   ./generate_artifactory_imports.sh
#
# Output:
#   imports.tf — feed into: terraform plan -generate-config-out=generated.tf
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
ARTIFACTORY_URL="${ARTIFACTORY_URL:?Please set ARTIFACTORY_URL}"
ARTIFACTORY_TOKEN="${ARTIFACTORY_TOKEN:?Please set ARTIFACTORY_TOKEN}"
OUTPUT_FILE="imports.tf"

# System users to skip — built-in, should not be managed by Terraform
SKIP_USERS="anonymous admin"

# Pagination size for APIs that support it
PAGE_SIZE=100

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────

# Sanitize a string into a valid Terraform resource name
tf_name() {
  echo "$1" | sed 's/[^a-zA-Z0-9_]/_/g'
}

# Artifactory API call
api_get() {
  local path="$1"
  curl -sf \
    -H "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
    -H "Content-Type: application/json" \
    "${ARTIFACTORY_URL}/artifactory/api${path}"
}

# Xray API call
xray_get() {
  local path="$1"
  curl -sf \
    -H "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
    -H "Content-Type: application/json" \
    "${ARTIFACTORY_URL}/xray/api${path}"
}

# Append an import block to the output file — skips duplicates
write_import() {
  local resource="$1"
  local name="$2"
  local id="$3"
  local key="${resource}.${name}"

  if grep -qxF "$key" "$SEEN_IMPORTS_FILE" 2>/dev/null; then
    echo "   ⏭️  Skipping duplicate import: ${key}"
    return
  fi
  echo "$key" >> "$SEEN_IMPORTS_FILE"

  cat >> "$OUTPUT_FILE" <<EOF
import {
  to = ${resource}.${name}
  id = "${id}"
}

EOF
}

# ── Package type → Terraform resource mapping ─────────────────────────────────
# NOTE: | is special in bash case patterns (means OR) — use _ as separator
repo_resource() {
  local type="$1"
  local pkg="$2"

  type=$(echo "$type" | tr '[:lower:]' '[:upper:]')
  pkg=$(echo "$pkg"   | tr '[:lower:]' '[:upper:]')
  local combined="${type}_${pkg}"

  case "$combined" in
    # ── Local ────────────────────────────────────────────────────────────────
    LOCAL_DOCKER)           echo "artifactory_local_docker_v2_repository" ;;
    LOCAL_MAVEN)            echo "artifactory_local_maven_repository" ;;
    LOCAL_NPM)              echo "artifactory_local_npm_repository" ;;
    LOCAL_PYPI)             echo "artifactory_local_pypi_repository" ;;
    LOCAL_HELM)             echo "artifactory_local_helm_repository" ;;
    LOCAL_GO)               echo "artifactory_local_go_repository" ;;
    LOCAL_GRADLE)           echo "artifactory_local_gradle_repository" ;;
    LOCAL_DEBIAN)           echo "artifactory_local_debian_repository" ;;
    LOCAL_RPM)              echo "artifactory_local_rpm_repository" ;;
    LOCAL_NUGET)            echo "artifactory_local_nuget_repository" ;;
    LOCAL_TERRAFORM)        echo "artifactory_local_terraform_module_repository" ;;
    LOCAL_TERRAFORMBACKEND) echo "artifactory_local_terraformbackend_repository" ;;
    LOCAL_GENERIC)          echo "artifactory_local_generic_repository" ;;
    LOCAL_RUBY)             echo "artifactory_local_gems_repository" ;;
    LOCAL_COMPOSER)         echo "artifactory_local_composer_repository" ;;
    LOCAL_CONAN)            echo "artifactory_local_conan_repository" ;;
    LOCAL_CHEF)             echo "artifactory_local_chef_repository" ;;
    LOCAL_PUPPET)           echo "artifactory_local_puppet_repository" ;;
    LOCAL_CARGO)            echo "artifactory_local_cargo_repository" ;;
    LOCAL_CONDA)            echo "artifactory_local_conda_repository" ;;
    LOCAL_HUGGINGFACEML)    echo "artifactory_local_hunggingfaceml_repository" ;;
    LOCAL_OCI)              echo "artifactory_local_oci_repository" ;;
    LOCAL_HELMOCI)          echo "artifactory_local_helmoci_repository" ;;
    LOCAL_MACHINELEARNING)  echo "artifactory_local_machine_learning_repository" ;;
    LOCAL_RELEASEBUNDLES)   echo "" ;; # Release Bundles are system-managed — skip
    # ── Remote ───────────────────────────────────────────────────────────────
    REMOTE_DOCKER)          echo "artifactory_remote_docker_repository" ;;
    REMOTE_MAVEN)           echo "artifactory_remote_maven_repository" ;;
    REMOTE_NPM)             echo "artifactory_remote_npm_repository" ;;
    REMOTE_PYPI)            echo "artifactory_remote_pypi_repository" ;;
    REMOTE_HELM)            echo "artifactory_remote_helm_repository" ;;
    REMOTE_GO)              echo "artifactory_remote_go_repository" ;;
    REMOTE_GRADLE)          echo "artifactory_remote_gradle_repository" ;;
    REMOTE_NUGET)           echo "artifactory_remote_nuget_repository" ;;
    REMOTE_GENERIC)         echo "artifactory_remote_generic_repository" ;;
    REMOTE_RUBY)            echo "artifactory_remote_gems_repository" ;;
    REMOTE_COMPOSER)        echo "artifactory_remote_composer_repository" ;;
    REMOTE_CONAN)           echo "artifactory_remote_conan_repository" ;;
    REMOTE_CARGO)           echo "artifactory_remote_cargo_repository" ;;
    REMOTE_CONDA)           echo "artifactory_remote_conda_repository" ;;
    REMOTE_OCI)             echo "artifactory_remote_oci_repository" ;;
    REMOTE_HELMOCI)         echo "artifactory_remote_helmoci_repository" ;;
    REMOTE_DEBIAN)          echo "artifactory_remote_debian_repository" ;;
    REMOTE_YUM)             echo "artifactory_remote_rpm_repository" ;;
    REMOTE_VCS)             echo "artifactory_remote_vcs_repository" ;;
    REMOTE_HUGGINGFACEML)   echo "artifactory_remote_huggingfaceml_repository" ;;
    REMOTE_P2)              echo "artifactory_remote_p2_repository" ;;
    # ── Virtual ──────────────────────────────────────────────────────────────
    VIRTUAL_DOCKER)         echo "artifactory_virtual_docker_repository" ;;
    VIRTUAL_MAVEN)          echo "artifactory_virtual_maven_repository" ;;
    VIRTUAL_NPM)            echo "artifactory_virtual_npm_repository" ;;
    VIRTUAL_PYPI)           echo "artifactory_virtual_pypi_repository" ;;
    VIRTUAL_HELM)           echo "artifactory_virtual_helm_repository" ;;
    VIRTUAL_GO)             echo "artifactory_virtual_go_repository" ;;
    VIRTUAL_GRADLE)         echo "artifactory_virtual_gradle_repository" ;;
    VIRTUAL_NUGET)          echo "artifactory_virtual_nuget_repository" ;;
    VIRTUAL_GENERIC)        echo "artifactory_virtual_generic_repository" ;;
    VIRTUAL_RUBY)           echo "artifactory_virtual_gems_repository" ;;
    VIRTUAL_COMPOSER)       echo "artifactory_virtual_composer_repository" ;;
    VIRTUAL_CONAN)          echo "artifactory_virtual_conan_repository" ;;
    VIRTUAL_OCI)            echo "artifactory_virtual_oci_repository" ;;
    VIRTUAL_HELMOCI)        echo "artifactory_virtual_helmoci_repository" ;;
    VIRTUAL_DEBIAN)         echo "artifactory_virtual_debian_repository" ;;
    VIRTUAL_HUGGINGFACEML)  echo "artifactory_virtual_huggingfaceml_repository" ;;
    # ── Federated ────────────────────────────────────────────────
    FEDERATED_DOCKER)       echo "artifactory_federated_docker_v2_repository" ;;
    FEDERATED_MAVEN)        echo "artifactory_federated_maven_repository" ;;
    FEDERATED_NPM)          echo "artifactory_federated_npm_repository" ;;
    FEDERATED_GENERIC)      echo "artifactory_federated_generic_repository" ;;
    FEDERATED_PYPI)         echo "artifactory_federated_pypi_repository" ;;
    FEDERATED_HELM)         echo "artifactory_federated_helm_repository" ;;
    FEDERATED_GO)           echo "artifactory_federated_go_repository" ;;
    FEDERATED_GRADLE)       echo "artifactory_federated_gradle_repository" ;;
    FEDERATED_NUGET)        echo "artifactory_federated_nuget_repository" ;;
    FEDERATED_DEBIAN)       echo "artifactory_federated_debian_repository" ;;
    FEDERATED_RPM)          echo "artifactory_federated_rpm_repository" ;;
    FEDERATED_OCI)          echo "artifactory_federated_oci_repository" ;;
    FEDERATED_TERRAFORM)    echo "artifactory_federated_terraform_module_repository" ;;
    FEDERATED_CONAN)        echo "artifactory_federated_conan_repository" ;;
    FEDERATED_CARGO)        echo "artifactory_federated_cargo_repository" ;;
    FEDERATED_BUILDINFO)    echo "" ;; # BuildInfo repos are system-managed — skip
    FEDERATED_RELEASEBUNDLES) echo "" ;; # Release Bundles are system-managed — skip
    *)
      echo ""  # unknown — will be skipped with a warning
      ;;
  esac
}

# ── Xray policy type → Terraform resource mapping ─────────────────────────────
xray_policy_resource() {
  local type="$1"
  type=$(echo "$type" | tr '[:upper:]' '[:lower:]')
  case "$type" in
    security)         echo "xray_security_policy" ;;
    license)          echo "xray_license_policy" ;;
    operational_risk) echo "xray_operational_risk_policy" ;;
    *)                echo "" ;;
  esac
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║    JFrog Terraform Import Generator              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

echo "# Generated by generate_artifactory_imports.sh" >  "$OUTPUT_FILE"
echo "# $(date)"                                       >> "$OUTPUT_FILE"
echo ""                                                >> "$OUTPUT_FILE"

TOTAL=0
REPO_SKIPPED=0

# Global tracker to prevent duplicate import blocks across all resources
SEEN_IMPORTS_FILE=$(mktemp)

# ── 1. Repositories ───────────────────────────────────────────────────────────
echo -e "⏳ Fetching repositories..."

repos_json=$(api_get "/repositories")
repo_count=$(echo "$repos_json" | jq 'length')
repo_total=0

echo "   Found ${repo_count} repositories"
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Repositories (jfrog/artifactory) ─────────────────────────────────────" >> "$OUTPUT_FILE"

while IFS= read -r line; do
  key=$(echo  "$line" | jq -r '.key'             | tr -d '[:space:]')
  type=$(echo "$line" | jq -r '.rclass // .type'  | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  pkg=$(echo  "$line" | jq -r '.packageType'      | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

  resource=$(repo_resource "$type" "$pkg")
  name=$(tf_name "$key")

  # System-managed repos — always skip silently
  if [[ "${type}_${pkg}" == "LOCAL_RELEASEBUNDLES" ]] || \
     [[ "${type}_${pkg}" == "FEDERATED_RELEASEBUNDLES" ]] || \
     [[ "${type}_${pkg}" == "FEDERATED_BUILDINFO" ]] || \
     [[ "${type}_${pkg}" == "LOCAL_MACHINELEARNING" ]] || \
     [[ "${type}_${pkg}" == "LOCAL_HUGGINGFACEML" ]] || \
     [[ "${type}_${pkg}" == "REMOTE_HUGGINGFACEML" ]] || \
     [[ "${type}_${pkg}" == "VIRTUAL_HUGGINGFACEML" ]] || \
     [[ "${pkg}" == "BUILDINFO" ]]; then
    ((REPO_SKIPPED++)) || true
    continue
  fi

  if [[ -z "$resource" ]]; then
    echo -e "   ${YELLOW}⚠️  Skipping $key — no Terraform resource for ${type}/${pkg}${NC}"
    ((REPO_SKIPPED++)) || true
    continue
  fi

  write_import "$resource" "$name" "$key"
  ((repo_total++)) || true

done < <(echo "$repos_json" | jq -c '.[]')

((TOTAL += repo_total)) || true
echo -e "   ${GREEN}✅ ${repo_total} repos imported (${REPO_SKIPPED} skipped)${NC}"

# ── 2. Users ──────────────────────────────────────────────────────────────────
echo -e "⏳ Fetching users..."

users_json=$(api_get "/security/users")
user_count=$(echo "$users_json" | jq 'length')
user_total=0
user_skipped=0

echo "   Found ${user_count} users"
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Users (jfrog/artifactory) ─────────────────────────────────────────────" >> "$OUTPUT_FILE"

while IFS= read -r username; do
  if echo "$SKIP_USERS" | grep -qw "$username"; then
    echo "   ⏭️  Skipping system user: $username"
    ((user_skipped++)) || true
    continue
  fi

  name=$(tf_name "$username")
  write_import "artifactory_unmanaged_user" "$name" "$username"
  ((user_total++)) || true

done < <(echo "$users_json" | jq -r '.[].name')

((TOTAL += user_total)) || true
echo -e "   ${GREEN}✅ ${user_total} users imported (${user_skipped} system users skipped)${NC}"

# ── 3. Groups ─────────────────────────────────────────────────────────────────
echo -e "⏳ Fetching groups..."

groups_json=$(api_get "/security/groups")
group_count=$(echo "$groups_json" | jq 'length')
group_total=0

echo "   Found ${group_count} groups"
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Groups (jfrog/platform) ───────────────────────────────────────────────" >> "$OUTPUT_FILE"

while IFS= read -r groupname; do
  name=$(tf_name "$groupname")
  write_import "platform_group" "$name" "$groupname"
  ((group_total++)) || true
done < <(echo "$groups_json" | jq -r '.[].name')

((TOTAL += group_total)) || true
echo -e "   ${GREEN}✅ ${group_total} groups imported${NC}"

# ── 4. Permissions ────────────────────────────────────────────────────────────
echo -e "⏳ Fetching permissions..."

perms_json=$(api_get "/security/permissions")
perm_count=$(echo "$perms_json" | jq 'length')
perm_total=0

echo "   Found ${perm_count} permissions"
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Permissions (jfrog/platform) ──────────────────────────────────────────" >> "$OUTPUT_FILE"

while IFS= read -r permname; do
  name=$(tf_name "$permname")
  write_import "platform_permission" "$name" "$permname"
  ((perm_total++)) || true
done < <(echo "$perms_json" | jq -r '.[].name')

((TOTAL += perm_total)) || true
echo -e "   ${GREEN}✅ ${perm_total} permissions imported${NC}"

# ── 5. Xray Policies ──────────────────────────────────────────────────────────
echo -e "⏳ Fetching Xray policies..."

xray_policies_json=$(xray_get "/v1/policies")
xray_policy_count=$(echo "$xray_policies_json" | jq 'length')
xray_policy_total=0
xray_policy_skipped=0

echo "   Found ${xray_policy_count} Xray policies"
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Xray Policies (jfrog/xray) ────────────────────────────────────────────" >> "$OUTPUT_FILE"

while IFS= read -r line; do
  pname=$(echo "$line" | jq -r '.name' | tr -d '[:space:]')
  ptype=$(echo "$line" | jq -r '.type' | tr -d '[:space:]')

  resource=$(xray_policy_resource "$ptype")
  name=$(tf_name "$pname")

  if [[ -z "$resource" ]]; then
    echo -e "   ${YELLOW}⚠️  Skipping Xray policy $pname — unknown type: ${ptype}${NC}"
    ((xray_policy_skipped++)) || true
    continue
  fi

  write_import "$resource" "$name" "$pname"
  ((xray_policy_total++)) || true

done < <(echo "$xray_policies_json" | jq -c '.[]')

((TOTAL += xray_policy_total)) || true
echo -e "   ${GREEN}✅ ${xray_policy_total} Xray policies imported (${xray_policy_skipped} skipped)${NC}"

# ── 6. Xray Watches ───────────────────────────────────────────────────────────
echo -e "⏳ Fetching Xray watches..."

watches_json=$(xray_get "/v2/watches")
watch_count=$(echo "$watches_json" | jq 'length')
watch_total=0

echo "   Found ${watch_count} Xray watches"
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Xray Watches (jfrog/xray) ─────────────────────────────────────────────" >> "$OUTPUT_FILE"

while IFS= read -r watchname; do
  name=$(tf_name "$watchname")
  write_import "xray_watch" "$name" "$watchname"
  ((watch_total++)) || true
done < <(echo "$watches_json" | jq -r '.[].general_data.name')

((TOTAL += watch_total)) || true
echo -e "   ${GREEN}✅ ${watch_total} Xray watches imported${NC}"

# ── 7. Curation Conditions ────────────────────────────────────────────────────
echo -e "⏳ Fetching curation conditions..."

# Paginate through all conditions
curation_cond_total=0
offset=0
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Curation Conditions (jfrog/xray) ──────────────────────────────────────" >> "$OUTPUT_FILE"

while true; do
  page_json=$(xray_get "/v1/curation/conditions?is_custom=true&num_of_rows=${PAGE_SIZE}&offset=${offset}")
  page_count=$(echo "$page_json" | jq '.data | length')

  if [[ "$page_count" -eq 0 ]]; then
    break
  fi

  while IFS= read -r line; do
    condid=$(echo "$line" | jq -r '.id' | tr -d '[:space:]')
    condname=$(echo "$line" | jq -r '.name' | tr -d '[:space:]')
    name=$(tf_name "$condname")
    write_import "xray_custom_curation_condition" "$name" "$condid"
    ((curation_cond_total++)) || true
  done < <(echo "$page_json" | jq -c '.data[]')

  if [[ "$page_count" -lt "$PAGE_SIZE" ]]; then
    break
  fi
  ((offset += PAGE_SIZE)) || true
done

((TOTAL += curation_cond_total)) || true
echo -e "   ${GREEN}✅ ${curation_cond_total} curation conditions imported${NC}"

# ── 8. Curation Policies ──────────────────────────────────────────────────────
echo -e "⏳ Fetching curation policies..."

curation_pol_total=0
offset=0
echo ""                                                                              >> "$OUTPUT_FILE"
echo "# ── Curation Policies (jfrog/xray) ────────────────────────────────────────" >> "$OUTPUT_FILE"

while true; do
  page_json=$(xray_get "/v1/curation/policies?num_of_rows=${PAGE_SIZE}&offset=${offset}")
  page_count=$(echo "$page_json" | jq '.data | length')

  if [[ "$page_count" -eq 0 ]]; then
    break
  fi

  while IFS= read -r line; do
    polid=$(echo "$line" | jq -r '.id' | tr -d '[:space:]')
    polname=$(echo "$line" | jq -r '.name' | tr -d '[:space:]')
    name=$(tf_name "$polname")
    write_import "xray_curation_policy" "$name" "$polid"
    ((curation_pol_total++)) || true
  done < <(echo "$page_json" | jq -c '.data[]')

  if [[ "$page_count" -lt "$PAGE_SIZE" ]]; then
    break
  fi
  ((offset += PAGE_SIZE)) || true
done

((TOTAL += curation_pol_total)) || true
echo -e "   ${GREEN}✅ ${curation_pol_total} curation policies imported${NC}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Resource                    Count${NC}"
echo -e "  ──────────────────────────────────────────────────"
echo -e "  Repositories              : ${repo_total}  (${REPO_SKIPPED} skipped)"
echo -e "  Users                     : ${user_total}  (${user_skipped} system users skipped)"
echo -e "  Groups                    : ${group_total}"
echo -e "  Permissions               : ${perm_total}"
echo -e "  Xray Policies             : ${xray_policy_total}  (${xray_policy_skipped} skipped)"
echo -e "  Xray Watches              : ${watch_total}"
echo -e "  Curation Conditions       : ${curation_cond_total}"
echo -e "  Curation Policies         : ${curation_pol_total}"
echo -e "  ──────────────────────────────────────────────────"
echo -e "  ${BOLD}Total import blocks       : ${TOTAL}${NC}"
echo -e "  Output file               : ${OUTPUT_FILE}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. terraform init"
echo "  2. terraform plan -generate-config-out=generated.tf"
echo "  3. Review generated.tf"
echo "  4. terraform apply"
echo ""