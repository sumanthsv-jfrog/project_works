#!/bin/sh
#
# jfrog-list-group-permissions.sh
#
# Exports a GROUP-centric CSV of JFrog Artifactory permissions, columns:
#   groupname, permission_name, repositories, permissions
#
# One row per (group, permission target). A group that belongs to several
# permission targets gets several rows. Rows are sorted by group name so all
# entries for a group are grouped together.
#
# - repositories : repos of that permission target, joined by "; "
# - permissions  : that group's privileges in that permission target
#
# Uses the Artifactory Security REST API (Permissions V1), stable across 7.x.
# Written for POSIX /bin/sh. Requirements: sh, curl, jq
#
# Usage:
#   export JFROG_URL="https://mycompany.jfrog.io/artifactory"
#   export JFROG_TOKEN="<access-token>"          # or JFROG_USER + JFROG_PASS
#   ./jfrog-list-group-permissions.sh                    # -> ./jfrog-group-permissions.csv
#   ./jfrog-list-group-permissions.sh -o /path/out.csv   # custom output file
#   ./jfrog-list-group-permissions.sh -g <group-name>    # only one group
#
# Permission letters (V1): m=manage d=delete w=deploy n=annotate r=read
#
set -eu

# ---------------------------------------------------------------------------
# Options / configuration
# ---------------------------------------------------------------------------
OUTPUT="${JFROG_CSV_OUT:-group_perm.csv}"
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

# ---------------------------------------------------------------------------
# jq program: emit one CSV row per GROUP in a permission target:
#   groupname, permission_name, repositories, permissions
# Emits nothing for targets that have no groups.
# ---------------------------------------------------------------------------
JQ_ROWS='
  def word:
    {"m":"manage","d":"delete","w":"deploy","n":"annotate","r":"read"}[.] // .;
  def privs: ([ .[] | word ] | join(", "));
  . as $d
  | ($d.repositories // [] | join("; ")) as $repos
  | ($d.principals.groups // {})
  | to_entries[]
  | [ .key, $d.name, $repos, (.value | privs) ]
  | @csv
'

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
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
echo "==> Found ${total} permission target(s). Scanning for groups ..." >&2

# Collect all group rows into a temp file, then sort by group name.
rows_file=$(mktemp)

while IFS= read -r name; do
  enc_name=$(printf '%s' "$name" | sed 's/ /+/g')

  if ! detail=$(api_get "/api/security/permissions/${enc_name}"); then
    echo "WARNING: could not fetch details for '${name}', skipping." >&2
    continue
  fi

  printf '%s' "$detail" | jq -r "$JQ_ROWS" >> "$rows_file"
done < "$names_file"
rm -f "$names_file"

# Optional single-group filter (match on the leading quoted group field).
if [ -n "$ONLY_GROUP" ]; then
  filtered=$(mktemp)
  grep -i "^\"${ONLY_GROUP}\"," "$rows_file" > "$filtered" || true
  mv "$filtered" "$rows_file"
fi

# Write header, then the group rows sorted alphabetically by group name.
echo "==> Writing CSV to ${OUTPUT} ..." >&2
{
  echo "groupname,permission_name,repositories,permissions"
  LC_ALL=C sort "$rows_file"
} > "$OUTPUT"

count=$(wc -l < "$rows_file" | tr -d ' ')
rm -f "$rows_file"

echo "==> Done. Wrote ${count} group row(s) to ${OUTPUT}" >&2