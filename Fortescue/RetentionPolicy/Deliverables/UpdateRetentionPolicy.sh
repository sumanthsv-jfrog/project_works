#!/bin/bash
#UpdateRetentionPolicy.sh
# Usage
usage() {
  echo "Usage: $0 <artifactory_url> <bearer_token> [repos_file]"
  echo ""
  echo "  artifactory_url  Artifactory base URL (e.g. https://your-artifactory.example.com)"
  echo "  bearer_token     Bearer token"
  echo "  policy_json      Policy JSON file (default: policy.json)"
  echo "  repos_file       Repos file (default: repos.txt)"
  exit 1
}

ARTIFACTORY_URL="${1:?ERROR: Artifactory URL is required. Usage: $0 <artifactory_url> <bearer_token>}"
TOKEN="${2:?ERROR: Bearer token is required. Usage: $0 <artifactory_url> <bearer_token>}"
REPOS_FILE="${3:-repos.txt}"
POLICY_NAME="sum-fortescue2"
POLICY_JSON="policy.json"

# Check files exist
if [[ ! -f "$POLICY_JSON" ]]; then
  echo "ERROR: $POLICY_JSON not found"
  exit 1
fi

if [[ ! -f "$REPOS_FILE" ]]; then
  echo "ERROR: $REPOS_FILE not found"
  exit 1
fi

# Read repos.txt and build JSON array
REPOS_ARRAY=$(awk 'NF' "$REPOS_FILE" | sed 's/^/"/;s/$/"/' | paste -sd ',' -)
REPOS_JSON="[$REPOS_ARRAY]"

echo "Repos to apply: $REPOS_JSON"

# Inject repos into Policy.json using jq
UPDATED_JSON=$(jq --argjson repos "$REPOS_JSON" \
  '.searchCriteria.repos = $repos' "$POLICY_JSON")

# Write to a temp file
TMP_FILE=$(mktemp /tmp/policy_XXXXXX.json)
echo "$UPDATED_JSON" > "$TMP_FILE"

echo "Creating policy: $(echo "$UPDATED_JSON" | jq -r '.key')"

# POST the policy
HTTP_STATUS=$(curl -s -o /tmp/policy_response.json -w "%{http_code}" \
  -X PUT "$ARTIFACTORY_URL/artifactory/api/cleanup/packages/policies/$POLICY_NAME" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -T "$TMP_FILE")

# Cleanup temp file
rm -f "$TMP_FILE"

# Check response
if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "201" ]]; then
  echo "✅ Policy updated successfully (HTTP $HTTP_STATUS)"
else
  echo "❌ Failed to create policy (HTTP $HTTP_STATUS)"
  echo "Response:"
  cat /tmp/policy_response.json
  exit 1
fi
