#!/usr/bin/env bash
#
# list-label-packages.sh
#
# Lists the packages (name + version) assigned to a JFrog Catalog custom label.
#
# Usage:
#   ./list-label-packages.sh <label-name>
#
# Edit the JFROG_URL and JFROG_TOKEN values below before running.
# (Environment variables, if set, will override these defaults.)
#
# Requires: curl, jq
#
set -euo pipefail

# ---- Configuration (edit these) ---------------------------------------------

JFROG_URL="${1:?Enter JFrog URL e.g. https://myorg.jfrog.io}"
JFROG_TOKEN="${2:?Enter JFrog Token}"
# ---- Input validation -------------------------------------------------------

LABEL_NAME="${3:-}"

if [[ -z "$LABEL_NAME" ]]; then
  echo "Usage: $0 <label-name>" >&2
  exit 1
fi

if [[ "$JFROG_URL" == "https://your-instance.jfrog.io" || "$JFROG_TOKEN" == "your-access-token" ]]; then
  echo "Error: edit JFROG_URL and JFROG_TOKEN at the top of this script first." >&2
  exit 1
fi

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' is required." >&2; exit 1; }
done

GRAPHQL_ENDPOINT="$JFROG_URL/catalog/api/v1/custom/graphql"

# ---- Helper: run a GraphQL query --------------------------------------------

run_query() {
  local query="$1"
  local response
  response=$(curl -s -X POST "$GRAPHQL_ENDPOINT" \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg q "$query" '{query: $q}')")

  if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
    echo "GraphQL error:" >&2
    echo "$response" | jq '.errors' >&2
    return 1
  fi

  echo "$response"
}

# ---- 1) Version-scoped packages (have a specific version) -------------------

list_versions() {
  local cursor="null"
  local has_next="true"
  local conn=".data.customCatalogLabel.getLabel.publicPackageVersionsConnection"

  while [[ "$has_next" == "true" ]]; do
    local after_arg=""
    [[ "$cursor" != "null" ]] && after_arg="after: \"$cursor\""

    local query="{ customCatalogLabel { getLabel(name: \"$LABEL_NAME\") {
      publicPackageVersionsConnection(first: 100 $after_arg) {
        edges { node { publicPackage { name type } version } }
        pageInfo { hasNextPage endCursor }
      }
    } } }"

    local response
    response=$(run_query "$query") || return 1

    echo "$response" | jq -r "${conn}.edges[]?.node
      | \"\(.publicPackage.name), \(.version), \(.publicPackage.type)\""

    has_next=$(echo "$response" | jq -r "${conn}.pageInfo.hasNextPage // false")
    cursor=$(echo "$response" | jq -r "${conn}.pageInfo.endCursor // \"null\"")
  done
}

# ---- 2) Package-scoped packages (label applies to whole package) ------------

list_packages() {
  local cursor="null"
  local has_next="true"
  local conn=".data.customCatalogLabel.getLabel.publicPackagesConnection"

  while [[ "$has_next" == "true" ]]; do
    local after_arg=""
    [[ "$cursor" != "null" ]] && after_arg="after: \"$cursor\""

    local query="{ customCatalogLabel { getLabel(name: \"$LABEL_NAME\") {
      publicPackagesConnection(first: 100 $after_arg) {
        edges { node { name type } }
        pageInfo { hasNextPage endCursor }
      }
    } } }"

    local response
    response=$(run_query "$query") || return 1

    # Package-scoped labels have no specific version
    echo "$response" | jq -r "${conn}.edges[]?.node
      | \"\(.name), (all versions), \(.type)\""

    has_next=$(echo "$response" | jq -r "${conn}.pageInfo.hasNextPage // false")
    cursor=$(echo "$response" | jq -r "${conn}.pageInfo.endCursor // \"null\"")
  done
}

# ---- Verify the label exists first ------------------------------------------

check_response=$(run_query "{ customCatalogLabel { getLabel(name: \"$LABEL_NAME\") { name } } }") || exit 1
if [[ "$(echo "$check_response" | jq -r '.data.customCatalogLabel.getLabel.name // "null"')" == "null" ]]; then
  echo "Label '$LABEL_NAME' not found." >&2
  exit 1
fi

# ---- Run ---------------------------------------------------------------------

echo "Packages in label '$LABEL_NAME':"
echo "--------------------------------"
echo "name, version, type"

{
  list_versions
  list_packages
} | sort -u

echo "--------------------------------"
