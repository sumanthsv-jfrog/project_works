#!/bin/sh
#
# jfrog-list-permissions.sh
#
# Exports ALL JFrog Artifactory permission targets to a CSV FILE with columns:
#   permission_name, repositories, groups_with_privileges, users_with_privileges
#
# - repositories            : repos joined by "; "
# - groups_with_privileges  : "group: read, deploy; group2: read"
# - users_with_privileges   : "user: read, deploy, annotate"
#
# Uses the Artifactory Security REST API (Permissions V1), stable across 7.x.
# Written for POSIX /bin/sh (no bash-only features).
#
# Requirements: sh, curl, jq
#
# Usage:
#   export JFROG_URL="https://mycompany.jfrog.io/artifactory"
#   export JFROG_TOKEN="<access-token>"          # or JFROG_USER + JFROG_PASS
#   ./jfrog-list-permissions.sh                       # -> ./jfrog-permissions.csv
#   ./jfrog-list-permissions.sh -o /path/out.csv      # custom output file
#   ./jfrog-list-permissions.sh -o one.csv <target>   # single target only
#
# Permission letters (V1): m=manage d=delete w=deploy n=annotate r=read
#
set -eu

# ---------------------------------------------------------------------------
# Options / configuration
# ---------------------------------------------------------------------------
OUTPUT="${JFROG_CSV_OUT:-permissions.csv}"   # default output file

while getopts "o:h" opt; do
  case "$opt" in
    o) OUTPUT="$OPTARG" ;;
    h) echo "usage: $0 [-o output.csv] [permission-target-name]" >&2; exit 0 ;;
    *) echo "usage: $0 [-o output.csv] [permission-target-name]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
ONLY_TARGET="${1:-}"

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
# Helper: authenticated GET. Prints body on stdout, returns non-zero on error.
# (Diagnostics go to stderr so they never end up in the CSV file.)
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

# ---------------------------------------------------------------------------
# jq program: render one permission target as a single CSV row.
# ---------------------------------------------------------------------------
JQ_ROW='
  def word:
    {"m":"manage","d":"delete","w":"deploy","n":"annotate","r":"read"}[.] // .;
  def privs: ([ .[] | word ] | join(", "));
  [
    .name,
    ((.repositories // []) | join("; ")),
    ((.principals.groups // {}) | to_entries
        | map("\(.key): \(.value | privs)") | join("; ")),
    ((.principals.users // {}) | to_entries
        | map("\(.key): \(.value | privs)") | join("; "))
  ] | @csv
'

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Get the list of ALL permission target names first.
echo "==> Connecting to ${JFROG_URL} ..." >&2
targets_json=$(api_get "/api/security/permissions") || exit 1

names_file=$(mktemp)
printf '%s\n' "$targets_json" | jq -r '.[].name' > "$names_file"

if [ ! -s "$names_file" ]; then
  echo "WARNING: no permission targets found." >&2
  rm -f "$names_file"
  exit 0
fi

total=$(wc -l < "$names_file" | tr -d ' ')
echo "==> Found ${total} permission target(s)." >&2
echo "==> Writing CSV to ${OUTPUT} ..." >&2

# Write the CSV header to the output file (truncating any existing file).
echo "permission_name,repositories,groups_with_privileges,users_with_privileges" > "$OUTPUT"

# Iterate over EVERY permission target and append one CSV row each.
count=0
while IFS= read -r name; do
  if [ -n "$ONLY_TARGET" ] && [ "$name" != "$ONLY_TARGET" ]; then
    continue
  fi

  enc_name=$(printf '%s' "$name" | sed 's/ /+/g')

  if ! detail=$(api_get "/api/security/permissions/${enc_name}"); then
    echo "WARNING: could not fetch details for '${name}', skipping." >&2
    continue
  fi

  printf '%s' "$detail" | jq -r "$JQ_ROW" >> "$OUTPUT"
  count=$((count + 1))
done < "$names_file"

rm -f "$names_file"

echo "==> Done. Wrote ${count} permission target(s) to ${OUTPUT}" >&2