#!/bin/bash
#
# list-waivers.sh
#
# Lists JFrog Curation waiver requests (packages requested to be unblocked).
# Endpoint: GET {JFROG_URL}/xray/api/v1/curation/waiver_requests
#
# Usage:
#   ./list-waivers.sh <JFROG_URL> <JFROG_TOKEN> [options]
#
# Options:
#   --status <approved|rejected|pending>   Filter by status (default: pending)
#   --pkg-type <type>                      Filter by package type (npm, pypi, ...)
#   --pkg-name <name>                      Filter by package name
#   --pkg-version <version>                Filter by package version
#   --can-approve                          Only requests the current user can approve
#   --rows <n>                             Rows per page (default: 50)
#   --csv                                  Output name,version,type CSV (feeds the label scripts)
#
# Requires: curl, jq
#
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
list-waivers.sh — list JFrog Curation waiver requests

USAGE:
  ./list-waivers.sh <JFROG_URL> <JFROG_TOKEN> [options]

ARGUMENTS:
  JFROG_URL      JFrog platform base URL, e.g. https://myorg.jfrog.io
  JFROG_TOKEN    Access token (Bearer)

OPTIONS:
  --status <approved|rejected|pending>   Filter by status (default: pending)
  --pkg-type <type>                      Filter by package type (npm, pypi, ...)
  --pkg-name <name>                      Filter by package name
  --pkg-version <version>                Filter by package version
  --can-approve                          Only requests the current user can approve
  --rows <n>                             Rows per page (default: 50)
  --json                                 Output raw JSON instead of CSV
  --csv                                  Output CSV (this is the default)
  -h, --help                             Show this help and exit

OUTPUT (CSV, default):
  Columns: name,version,type,status,id,repo_key,created_at,closed_at,
           waiver_expiry,waiver_expiry_status,requesters
  Multiple requesters are de-duplicated and joined with ';'.
  The first three columns are name,version,type so you can feed the
  label scripts directly:   ... --status approved | tail -n +2 | cut -d, -f1-3

EXAMPLES:
  # Approved waivers as CSV (default)
  ./list-waivers.sh https://myorg.jfrog.io "$TOKEN" --status approved

  # Feed approved waivers into the label scripts (name,version,type only)
  ./list-waivers.sh https://myorg.jfrog.io "$TOKEN" --status approved \
    | tail -n +2 | cut -d, -f1-3 | sort -u > waivers.csv

  # Raw JSON for inspection
  ./list-waivers.sh https://myorg.jfrog.io "$TOKEN" --json

REQUIRES: curl, jq
EOF
}

# Show help if requested (works in any position, before required-arg checks)
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done

JFROG_URL="${1:?Enter JFrog URL e.g. https://myorg.jfrog.io (use -h for help)}"
JFROG_TOKEN="${2:?Enter JFrog Token (use -h for help)}"
shift 2

# ── Defaults ──────────────────────────────────────────────────────────────────

STATUS="pending"
PKG_TYPE=""
PKG_NAME=""
PKG_VERSION=""
CAN_APPROVE="false"
ROWS=50
OUTPUT="csv"          # csv (default) or json

# ── Parse options ─────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)       STATUS="$2"; shift 2 ;;
    --pkg-type)     PKG_TYPE="$2"; shift 2 ;;
    --pkg-name)     PKG_NAME="$2"; shift 2 ;;
    --pkg-version)  PKG_VERSION="$2"; shift 2 ;;
    --can-approve)  CAN_APPROVE="true"; shift ;;
    --rows)         ROWS="$2"; shift 2 ;;
    --json)         OUTPUT="json"; shift ;;
    --csv)          OUTPUT="csv"; shift ;;   # default; kept for back-compat
    -h|--help)      usage; exit 0 ;;
    *) echo "Unknown option: $1 (use -h for help)" >&2; exit 1 ;;
  esac
done

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' is required." >&2; exit 1; }
done

ENDPOINT="$JFROG_URL/xray/api/v1/curation/waiver_requests"

# ── Fetch a single page ───────────────────────────────────────────────────────
# Uses zero-indexed offsets instead of page numbers to ensure correct API consumption.

fetch_page() {
  local page="$1"
  local offset=$(( (page - 1) * ROWS ))

  set -- -s -G "$ENDPOINT" \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    --data-urlencode "status=$STATUS" \
    --data-urlencode "can_approve=$CAN_APPROVE" \
    --data-urlencode "num_of_rows=$ROWS" \
    --data-urlencode "offset=$offset" \
    --data-urlencode "order_by=updated_at" \
    --data-urlencode "direction=desc"

  [ -n "$PKG_TYPE" ]    && set -- "$@" --data-urlencode "pkg_type=$PKG_TYPE"
  [ -n "$PKG_NAME" ]    && set -- "$@" --data-urlencode "pkg_name=$PKG_NAME"
  [ -n "$PKG_VERSION" ] && set -- "$@" --data-urlencode "pkg_version=$PKG_VERSION"

  curl "$@"
}

# ── Extract the array of rows regardless of wrapper key ───────────────────────

extract_rows() {
  jq -c 'if type=="array" then .
         elif .data then .data
         elif .waiver_requests then .waiver_requests
         elif .requests then .requests
         elif .rows then .rows
         else [] end'
}

# ── Main: paginate ────────────────────────────────────────────────────────────

if [ "$OUTPUT" = "csv" ]; then
  echo "name,version,type,status,id,repo_key,created_at,closed_at,waiver_expiry,waiver_expiry_status,requesters"
fi

page=1
total=0
prev_first_id=""        # Detect an API that repeats page 1 data due to offset anomalies
MAX_PAGES=1000          # Safety cap to avoid an infinite loop

while [ "$page" -le "$MAX_PAGES" ]; do
  response="$(fetch_page "$page")"

  # Surface HTTP/permission errors that come back as JSON
  if echo "$response" | jq -e '.errors // .error // empty' >/dev/null 2>&1; then
    echo "API error on page $page:" >&2
    echo "$response" | jq '.' >&2
    exit 1
  fi

  rows="$(echo "$response" | extract_rows)"
  count="$(echo "$rows" | jq 'length')"

  # Empty page => we've gone past the last page; done.
  [ "$count" -eq 0 ] && break

  # Guard: If data isn't changing, stop loop to prevent hitting API endlessly
  first_id="$(echo "$rows" | jq -r '.[0].id // .[0] | tostring')"
  if [ "$page" -gt 1 ] && [ "$first_id" = "$prev_first_id" ]; then
    echo "Warning: page $page repeated page $((page-1)) data; stopping pagination." >&2
    break
  fi
  prev_first_id="$first_id"

  if [ "$OUTPUT" = "csv" ]; then
    # name,version,type first (so `cut -d, -f1-3` feeds the label scripts).
    # Multiple requesters are reduced to unique users joined by ';'.
    echo "$rows" | jq -r '.[]
      | [ (.pkg_name             // ""),
          (.pkg_version          // ""),
          (.pkg_type             // ""),
          (.status               // ""),
          (.id                   // "" | tostring),
          (.repo_key             // ""),
          (.created_at           // ""),
          (.closed_at            // ""),
          (.waiver_expiry        // ""),
          (.waiver_expiry_status // ""),
          ([.requesters[]?.user] | unique | join(";")) ]
      | join(",")'
  else
    echo "$rows" | jq '.'
  fi

  total=$((total + count))
  page=$((page + 1))
done

[ "$OUTPUT" != "csv" ] && echo "Total waiver requests (status=$STATUS): $total" >&2
