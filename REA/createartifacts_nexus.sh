#!/usr/bin/env bash
#
# Creates sum- prefixed Maven, npm, and raw (generic) repositories in Nexus.
# Each format gets a proxy (remote), hosted (local), and group repo.
#
# Usage:
#   export NEXUS_PASSWORD='your-admin-password'
#   ./create-sum-repos.sh
#
set -euo pipefail

NEXUS="${NEXUS:-http://172.18.98.95:8081}"
USER="${NEXUS_USER:-admin}"
PASS="${NEXUS_PASSWORD:-1Q2w3e4r}"
API="$NEXUS/service/rest/v1/repositories"

# create <format/type> <json>
create() {
  local path="$1" body="$2" name
  name=$(echo "$body" | grep -o '"name": *"[^"]*"' | head -1 | cut -d'"' -f4)
  local code
  code=$(curl -s -o /tmp/nexus_resp -w '%{http_code}' \
    -u "$USER:$PASS" -X POST "$API/$path" \
    -H 'Content-Type: application/json' -d "$body")
  if [[ "$code" == "201" ]]; then
    echo "  [created]  $name"
  elif [[ "$code" == "400" ]] && grep -qi 'already exists\|name.*in use' /tmp/nexus_resp; then
    echo "  [exists]   $name (skipped)"
  else
    echo "  [FAILED]   $name -> HTTP $code: $(cat /tmp/nexus_resp)"
  fi
}

echo "Creating Maven repositories..."
create maven/proxy '{
  "name":"sum-maven-central","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
  "proxy":{"remoteUrl":"https://repo1.maven.org/maven2/","contentMaxAge":-1,"metadataMaxAge":1440},
  "negativeCache":{"enabled":true,"timeToLive":1440},
  "httpClient":{"blocked":false,"autoBlock":true},
  "maven":{"versionPolicy":"RELEASE","layoutPolicy":"STRICT"}
}'
create maven/hosted '{
  "name":"sum-maven-releases","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true,"writePolicy":"ALLOW_ONCE"},
  "maven":{"versionPolicy":"RELEASE","layoutPolicy":"STRICT"}
}'
create maven/hosted '{
  "name":"sum-maven-snapshots","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true,"writePolicy":"ALLOW"},
  "maven":{"versionPolicy":"SNAPSHOT","layoutPolicy":"STRICT"}
}'
create maven/group '{
  "name":"sum-maven-public","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
  "group":{"memberNames":["sum-maven-releases","sum-maven-snapshots","sum-maven-central"]}
}'

echo "Creating npm repositories..."
create npm/proxy '{
  "name":"sum-npm-proxy","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
  "proxy":{"remoteUrl":"https://registry.npmjs.org","contentMaxAge":1440,"metadataMaxAge":1440},
  "negativeCache":{"enabled":true,"timeToLive":1440},
  "httpClient":{"blocked":false,"autoBlock":true}
}'
create npm/hosted '{
  "name":"sum-npm-hosted","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true,"writePolicy":"ALLOW"}
}'
create npm/group '{
  "name":"sum-npm-group","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
  "group":{"memberNames":["sum-npm-hosted","sum-npm-proxy"]}
}'

echo "Creating raw (generic) repositories..."
create raw/proxy '{
  "name":"sum-raw-proxy","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
  "proxy":{"remoteUrl":"https://repo1.maven.org/maven2/","contentMaxAge":1440,"metadataMaxAge":1440},
  "negativeCache":{"enabled":true,"timeToLive":1440},
  "httpClient":{"blocked":false,"autoBlock":true},
  "raw":{"contentDisposition":"ATTACHMENT"}
}'
create raw/hosted '{
  "name":"sum-raw-hosted","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true,"writePolicy":"ALLOW"},
  "raw":{"contentDisposition":"ATTACHMENT"}
}'
create raw/group '{
  "name":"sum-raw-group","online":true,
  "storage":{"blobStoreName":"default","strictContentTypeValidation":true},
  "group":{"memberNames":["sum-raw-hosted","sum-raw-proxy"]},
  "raw":{"contentDisposition":"ATTACHMENT"}
}'

echo "Done. Listing all sum- repositories:"
curl -s -u "$USER:$PASS" "$API" \
  | grep -o '"name": *"sum-[^"]*"' | cut -d'"' -f4 | sort
