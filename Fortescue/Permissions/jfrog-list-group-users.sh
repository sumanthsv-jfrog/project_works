#!/bin/sh
#
# jfrog-list-group-users.sh
#
# Exports a CSV of JFrog Artifactory groups and their member users, columns:
#   groupname, usernames
#
# One row per group. "usernames" is the group's members joined by "; ".
# Rows are sorted alphabetically by group name.
#
# Uses the Artifactory Security REST API (read-only):
#   GET /api/security/groups                              (list group names)
#   GET /api/security/groups/{name}?includeUsers=true     (members of a group)
# 'includeUsers=true' has been supported since Artifactory 6.13.
#
# READ-ONLY: only HTTP GET is used; nothing on the server is created,
# modified, or deleted. The only writes are the local CSV + temp files.
# API calls made: 1 + G, where G is the number of groups.
#
# Written for POSIX /bin/sh. Requirements: sh, curl, jq
#
# Usage:
#   export JFROG_URL="https://mycompany.jfrog.io/artifactory"
#   export JFROG_TOKEN="<access-token>"          # or JFROG_USER + JFROG_PASS
#   ./jfrog-list-group-users.sh                       # -> ./group_users.csv
#   ./jfrog-list-group-users.sh -o /path/out.csv      # custom output file
#   ./jfrog-list-group-users.sh -g <group-name>       # only one group
#
set -eu

# ---------------------------------------------------------------------------
# Options / configuration
# ---------------------------------------------------------------------------
OUTPUT="${JFROG_CSV_OUT:-group_users.csv}"
ONLY_GROUP=""

while getopts "o:g:h" opt; do
  case "$opt" in
    o) OUTPUT="$OPTARG" ;;
    g) ONLY_GROUP="$OPTARG" ;;
    h) echo "usage: $0 [-o output.csv] [-g group-name]" >&2; exit 0 ;;
    *) echo "usage: $0 [-o output.csv] [-g group-name]" >&2; exit 1 ;;
  esac
done

JFROG_URL="${JFROG_URL:-}"
JFROG_TOKEN="${JFROG_TOKEN:-}"
JFROG_USER="${JFROG_USER:-}"
JFROG_PASS="${JFROG_PASS:-}"

if [ -z "$JFROG_URL" ]; then
  echo "ERROR: set JFROG_URL (e.g. https://mycompany.jfrog.io/artifactory)" >&2
  exit 1
fi

case "$JFROG_URL" in
  */) JFROG_URL="${JFROG_URL%/}" ;;
esac

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: '$bin' is required but not installed." >&2; exit 1; }
done

if [ -z "$JFROG_TOKEN" ] && { [ -z "$JFROG_USER" ] || [ -z "$JFROG_PASS" ]; }; then
  echo "ERROR: provide auth via JFROG_TOKEN, or JFROG_USER + JFROG_PASS." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: authenticated GET. Prints body on stdout, non-zero on error.
# ---------------------------------------------------------------------------
api_get() {
  _path="$1"
  _tmp=$(mktemp)

  if [ -n "$JFROG_TOKEN" ]; then
    _code=$(curl -sS -w '%{http_code}' -o "$_tmp" \
              -H "Authorization: Bearer ${JFROG_TOKEN}" \
              "${JFROG_URL}${_path}") || {
      echo "ERROR: curl failed for ${_path}" >&2; rm -f "$_tmp"; return 1; }
  else
    _code=$(curl -sS -w '%{http_code}' -o "$_tmp" \
              -u "${JFROG_USER}:${JFROG_PASS}" \
              "${JFROG_URL}${_path}") || {
      echo "ERROR: curl failed for ${_path}" >&2; rm -f "$_tmp"; return 1; }
  fi

  if [ "$_code" -lt 200 ] || [ "$_code" -ge 300 ]; then
    echo "ERROR: GET ${_path} returned HTTP ${_code}" >&2
    cat "$_tmp" >&2
    rm -f "$_tmp"
    return 1
  fi

  cat "$_tmp"
  rm -f "$_tmp"
}

# jq: build one CSV row [groupname, usernames]. Accepts either userNames or
# usersNames as the member field, depending on Artifactory version.
JQ_ROW='[ $g, ((.userNames // .usersNames // []) | join("; ")) ] | @csv'

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "==> Connecting to ${JFROG_URL} ..." >&2
groups_json=$(api_get "/api/security/groups") || exit 1

names_file=$(mktemp)
printf '%s\n' "$groups_json" | jq -r '.[].name' > "$names_file"

if [ ! -s "$names_file" ]; then
  echo "WARNING: no groups found." >&2
  rm -f "$names_file"
  exit 0
fi

total=$(wc -l < "$names_file" | tr -d ' ')
echo "==> Found ${total} group(s). Fetching members ..." >&2

rows_file=$(mktemp)

while IFS= read -r name; do
  if [ -n "$ONLY_GROUP" ] && [ "$name" != "$ONLY_GROUP" ]; then
    continue
  fi

  enc_name=$(printf '%s' "$name" | sed 's/ /+/g')

  if ! detail=$(api_get "/api/security/groups/${enc_name}?includeUsers=true"); then
    echo "WARNING: could not fetch members for '${name}', skipping." >&2
    continue
  fi

  printf '%s' "$detail" | jq -r --arg g "$name" "$JQ_ROW" >> "$rows_file"
done < "$names_file"
rm -f "$names_file"

echo "==> Writing CSV to ${OUTPUT} ..." >&2
{
  echo "groupname,usernames"
  LC_ALL=C sort "$rows_file"
} > "$OUTPUT"

count=$(wc -l < "$rows_file" | tr -d ' ')
rm -f "$rows_file"

echo "==> Done. Wrote ${count} group(s) to ${OUTPUT}" >&2
