#!/usr/bin/env bash
#
# get-repo-permissions.sh
# Fetch effective permissions for Artifactory repositories and export to CSV.
# Bash port of get_repo_permissions.py.
#
# Repository selection (choose exactly one):
#   -f FILE     File with repo keys, one per line (# comments and blank lines ignored)
#   -type TYPE  Fetch all repos of TYPE: local | remote | virtual | federated
#
# Inputs:
#   -u URL      Artifactory base URL   (/artifactory auto-appended if missing)
#   -t TOKEN    Bearer token           (admin scope required)
#   -o DIR      Output base directory  (default: reports)
#
# Output layout:
#   reports/<YYYY-MM-DD>/<HH-MM-SS>/
#     repo_permissions_report.csv       — flattened permission rows (detail)
#     repo_permissions_summary.csv      — one row per repo: repo,users,groups
#                                         (users and groups colon-separated)
#     permissions/<repo>.json           — raw API responses (one per repo)
#     repos_to_process.txt              — resolved repo list
#     get_repo_permissions.log          — full run log
#
# Examples:
#   ./get-repo-permissions.sh -u https://psblr.jfrog.io -t "$JF_TOKEN" -f repos.txt
#   ./get-repo-permissions.sh -u https://psblr.jfrog.io -t "$JF_TOKEN" -type remote
#

set -euo pipefail

ART_URL=""
TOKEN=""
REPO_FILE=""
REPO_TYPE=""
OUT_BASE="reports"

CSV_HEADERS="repo_name,principal_type,principal,admin,delete,deploy,annotate,read,distribute,managedXrayMeta,permission_targets,permission_targets_count,permission_targets_cap"

usage() {
    cat <<EOF
Usage: $(basename "$0") -u <url> -t <token> (-f <file> | -type <local|remote|virtual|federated>) [-o <dir>]

Selection (choose one):
  -f FILE       File with repo keys (one per line)
  -type TYPE    Fetch all repos of TYPE: local | remote | virtual | federated

Options:
  -o DIR        Output base directory (default: reports)
  -h            Show this help
EOF
    exit 0
}

# ---------- parse args -------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u)         ART_URL="$2";   shift 2 ;;
        -t)         TOKEN="$2";     shift 2 ;;
        -f)         REPO_FILE="$2"; shift 2 ;;
        -type)      REPO_TYPE="$2"; shift 2 ;;
        -o)         OUT_BASE="$2";  shift 2 ;;
        -h|--help)  usage ;;
        *) echo "Unknown argument: $1" >&2; usage ;;
    esac
done

# ---------- validate ---------------------------------------------------------
if [[ -z "$ART_URL" || -z "$TOKEN" ]]; then usage; fi

if [[ -n "$REPO_FILE" && -n "$REPO_TYPE" ]]; then
    echo "ERROR: use either -f or -type, not both" >&2; exit 1
fi
if [[ -z "$REPO_FILE" && -z "$REPO_TYPE" ]]; then
    echo "ERROR: provide a selection: -f <file> or -type <local|remote|virtual|federated>" >&2; exit 1
fi
if [[ -n "$REPO_FILE" && ! -f "$REPO_FILE" ]]; then
    echo "ERROR: file not found: $REPO_FILE" >&2; exit 1
fi
if [[ -n "$REPO_TYPE" ]]; then
    case "$REPO_TYPE" in
        local|remote|virtual|federated) ;;
        *) echo "ERROR: -type must be one of: local, remote, virtual, federated (got: $REPO_TYPE)" >&2; exit 1 ;;
    esac
fi

# Normalize URL
ART_URL="${ART_URL%/}"
[[ "$ART_URL" != */artifactory ]] && ART_URL="${ART_URL}/artifactory"

# ---------- output layout ----------------------------------------------------
DATE_STR=$(date +%Y-%m-%d)
TIME_STR=$(date +%H-%M-%S)
OUT_DIR="$OUT_BASE/$DATE_STR/$TIME_STR"
JSON_DIR="$OUT_DIR/permissions"
REPOS_LIST="$OUT_DIR/repos_to_process.txt"
CSV_OUT="$OUT_DIR/repo_permissions_report.csv"
SUMMARY_CSV="$OUT_DIR/repo_permissions_summary.csv"
LOG_FILE="$OUT_DIR/get_repo_permissions.log"
mkdir -p "$JSON_DIR"

# ---------- helpers ----------------------------------------------------------
log() {
    local msg
    msg="[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

# ---------- functions --------------------------------------------------------

# Build the list of repo keys to process (from file or by fetching from API).
build_repo_list() {
    if [[ -n "$REPO_FILE" ]]; then
        log "Loading repo list from $REPO_FILE ..."
        grep -v '^\s*#' "$REPO_FILE" | tr -d ' \r' | grep -v '^$' > "$REPOS_LIST" || true
    else
        log "Fetching all '$REPO_TYPE' repositories from Artifactory ..."
        curl -s -H "Authorization: Bearer $TOKEN" \
            "$ART_URL/api/repositories?type=$REPO_TYPE" 2>/dev/null \
          | jq -r '.[].key' 2>/dev/null > "$REPOS_LIST" || true
    fi
    local count
    count=$(wc -l < "$REPOS_LIST" | tr -d ' ')
    log "Repositories to process: $count"

    if [[ "$count" -eq 0 ]]; then
        log "ERROR: no repositories to process. Aborting."
        exit 1
    fi
}

# Fetch effective permissions for one repo, save raw JSON.
# Returns 0 on HTTP 200, non-zero otherwise.
fetch_repo_permissions() {
    local repo="$1"
    local out_json="$JSON_DIR/${repo}.json"
    local code
    code=$(curl -s -o "$out_json" -w "%{http_code}" \
        -H "Authorization: Bearer $TOKEN" \
        "$ART_URL/api/artifactpermissions?repoKey=${repo}" 2>/dev/null)
    [[ "$code" == "200" ]]
}

# Flatten one repo's JSON into CSV rows (user + group entries) and append.
flatten_to_csv() {
    local repo="$1"
    local json="$JSON_DIR/${repo}.json"

    jq -r --arg repo "$repo" '
        def flatten($type; $entries):
            $entries[]?
            | [ $repo,
                $type,
                (.principal // ""),
                (.admin // false),
                (.permission.delete // false),
                (.permission.deploy // false),
                (.permission.annotate // false),
                (.permission.read // false),
                (.permission.distribute // false),
                (.permission.managedXrayMeta // false),
                ((.permissionTargets // []) | join("|")),
                (.permissionTargetsCount // 0),
                (.permissionTargetsCap // false)
              ] | @csv;
        flatten("user";  .userEffectivePermissions  // []),
        flatten("group"; .groupEffectivePermissions // [])
    ' "$json" 2>/dev/null >> "$CSV_OUT"
}

# One-line-per-repo summary: repo,users,groups
# Users and groups are colon-separated lists so you can see at a glance
# who has access to each repo without scanning many detail rows.
flatten_summary_row() {
    local repo="$1"
    local json="$JSON_DIR/${repo}.json"

    jq -r --arg repo "$repo" '
        [ $repo,
          ((.userEffectivePermissions  // []) | map(.principal) | unique | join(":")),
          ((.groupEffectivePermissions // []) | map(.principal) | unique | join(":"))
        ] | @csv
    ' "$json" 2>/dev/null >> "$SUMMARY_CSV"
}

# Iterate the repo list, fetch + flatten each, write summary.
process_repos() {
    echo "$CSV_HEADERS" > "$CSV_OUT"
    echo "repo_name,users,groups" > "$SUMMARY_CSV"

    local total=0 success=0 failed=0 user_rows=0 group_rows=0
    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        total=$((total + 1))
        log "Processing repo: $repo"

        if fetch_repo_permissions "$repo"; then
            flatten_to_csv "$repo"
            flatten_summary_row "$repo"

            local repo_json="$JSON_DIR/${repo}.json"
            local added_user added_group
            added_user=$(jq  '(.userEffectivePermissions  // []) | length' "$repo_json" 2>/dev/null || echo 0)
            added_group=$(jq '(.groupEffectivePermissions // []) | length' "$repo_json" 2>/dev/null || echo 0)
            log "  -> ${added_user:-0} user entries, ${added_group:-0} group entries"

            user_rows=$((user_rows + ${added_user:-0}))
            group_rows=$((group_rows + ${added_group:-0}))
            success=$((success + 1))
        else
            log "  -> failed to fetch permissions for '$repo'"
            failed=$((failed + 1))
        fi
    done < "$REPOS_LIST"

    local total_rows=$((user_rows + group_rows))
    log "============================================================"
    log "Done. Processed: $success | Failed: $failed | Detail rows: $total_rows"
    log "Detail CSV  : $CSV_OUT"
    log "Summary CSV : $SUMMARY_CSV"
    log "JSON files  : $JSON_DIR"
    log "Log file    : $LOG_FILE"
}

# ---------- main -------------------------------------------------------------
log "=== Artifactory Effective Repository Permissions Report ==="
log "Artifactory URL : $ART_URL"
if [[ -n "$REPO_FILE" ]]; then
    log "Repo file       : $REPO_FILE"
else
    log "Repo type       : $REPO_TYPE"
fi
log "Output directory: $OUT_DIR"
log "JSON directory  : $JSON_DIR"

build_repo_list
process_repos