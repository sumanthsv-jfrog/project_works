#!/bin/bash
#
# decide-waiver-requests.sh
#
# Approve or reject JFrog Curation waiver requests from a CSV file.
# Endpoint: POST {JFROG_URL}/xray/api/v1/curation/waiver_requests/{id}/decision
#
# Usage:
#   ./decide-waiver-requests.sh <JFROG_URL> <JFROG_TOKEN> [input.csv] [options]
#
# Input CSV columns:
#   id,status[,justification[,duration_days]]
#
#   status must be "approved" or "rejected" (aliases: approve, reject).
#   justification and duration_days are optional per row; missing values use
#   script defaults (--duration-days, --approve-justification, --reject-justification).
#   duration_days is only sent for approved requests.
#
# Requires: curl, jq
#
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
decide-waiver-requests.sh — approve or reject JFrog Curation waiver requests

USAGE:
  ./decide-waiver-requests.sh <JFROG_URL> <JFROG_TOKEN> [input.csv] [options]

ARGUMENTS:
  JFROG_URL      JFrog platform base URL, e.g. https://myorg.jfrog.io
  JFROG_TOKEN    Access token (Bearer)
  input.csv      CSV file (default: waiver-decisions.csv)

INPUT CSV:
  id,status[,justification[,duration_days]]

  Examples:
    id,status
    1429,approved
    6,rejected
    10,approved,No exploitable path in our usage.,7

OPTIONS:
  --duration-days <n>              Default waiver duration for approvals (default: 3)
  --approve-justification <text>   Default justification for approved rows
  --reject-justification <text>    Default justification for rejected rows
  --dry-run                        Print requests without calling the API
  -h, --help                       Show this help and exit

EXAMPLES:
  # Decide all rows in waiver-decisions.csv
  ./decide-waiver-requests.sh "$JFROG_URL" "$JFROG_TOKEN"

  # Custom input file and 7-day approvals
  ./decide-waiver-requests.sh "$JFROG_URL" "$JFROG_TOKEN" decisions.csv --duration-days 7

  # Build input from pending waivers (id + decision only)
  ./list-waivers.sh "$JFROG_URL" "$JFROG_TOKEN" --status pending \
    | tail -n +2 | cut -d, -f5 | sed 's/$/,approved/' > waiver-decisions.csv

  # Preview payloads
  ./decide-waiver-requests.sh "$JFROG_URL" "$JFROG_TOKEN" waiver-decisions.csv --dry-run

REQUIRES: curl, jq
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
  esac
done

JFROG_URL="${1:?Enter JFrog URL e.g. https://myorg.jfrog.io (use -h for help)}"
JFROG_TOKEN="${2:?Enter JFrog Token (use -h for help)}"
shift 2

INPUT_FILE="waiver-decisions.csv"
if [[ $# -gt 0 && "$1" != --* ]]; then
  INPUT_FILE="$1"
  shift
fi

# ── Defaults ──────────────────────────────────────────────────────────────────

DURATION_DAYS=15
APPROVE_JUSTIFICATION="Reviewed dependency; no exploitable path in our usage. Approved per security review."
REJECT_JUSTIFICATION="Does not meet security review criteria. Rejected."
DRY_RUN="false"

# ── Parse options ─────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration-days)          DURATION_DAYS="$2"; shift 2 ;;
    --approve-justification)  APPROVE_JUSTIFICATION="$2"; shift 2 ;;
    --reject-justification)   REJECT_JUSTIFICATION="$2"; shift 2 ;;
    --dry-run)                DRY_RUN="true"; shift ;;
    -h|--help)                usage; exit 0 ;;
    *) echo "Unknown option: $1 (use -h for help)" >&2; exit 1 ;;
  esac
done

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: '$cmd' is required." >&2; exit 1; }
done

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: input file '$INPUT_FILE' not found." >&2
  echo "Expected CSV with columns: id,status[,justification[,duration_days]]" >&2
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

normalize_status() {
  local raw
  raw="$(trim "$(echo "$1" | tr '[:upper:]' '[:lower:]')")"
  case "$raw" in
    approved|approve) echo "approved" ;;
    rejected|reject)  echo "rejected" ;;
    *)
      echo "Error: invalid status '$1' (use approved or rejected)" >&2
      return 1
      ;;
  esac
}

build_payload() {
  local status="$1"
  local justification="$2"
  local duration="$3"

  if [[ "$status" == "approved" ]]; then
    jq -n \
      --arg status "$status" \
      --arg justification "$justification" \
      --argjson duration_days "$duration" \
      '{status: $status, justification: $justification, duration_days: $duration_days}'
  else
    jq -n \
      --arg status "$status" \
      --arg justification "$justification" \
      '{status: $status, justification: $justification}'
  fi
}

submit_decision() {
  local id="$1"
  local payload="$2"
  local endpoint="$JFROG_URL/xray/api/v1/curation/waiver_requests/$id/decision"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN POST $endpoint"
    echo "$payload" | jq '.'
    return 0
  fi

  local response http_code body
  response="$(curl -sS -w $'\n%{http_code}' -X POST "$endpoint" \
    -H "Authorization: Bearer $JFROG_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload")"

  http_code="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [[ "$http_code" =~ ^2 ]]; then
    echo "OK   id=$id (HTTP $http_code)"
    return 0
  fi

  echo "FAIL id=$id (HTTP $http_code)" >&2
  if [[ -n "$body" ]]; then
    if echo "$body" | jq -e . >/dev/null 2>&1; then
      echo "$body" | jq '.' >&2
    else
      echo "$body" >&2
    fi
  fi
  return 1
}

# ── Main ──────────────────────────────────────────────────────────────────────

TOTAL=0
APPROVED=0
REJECTED=0
FAILED=0
LINE_NO=0

while IFS=',' read -r col1 col2 col3 col4 _rest || [[ -n "${col1:-}" ]]; do
  LINE_NO=$((LINE_NO + 1))

  # Trim whitespace
  col1="$(trim "${col1:-}")"
  col2="$(trim "${col2:-}")"
  col3="$(trim "${col3:-}")"
  col4="$(trim "${col4:-}")"

  [[ -z "$col1" ]] && continue
  [[ "$col1" == "id" ]] && continue
  [[ "$col1" == \#* ]] && continue

  if [[ ! "$col1" =~ ^[0-9]+$ ]]; then
    echo "Error: line $LINE_NO: invalid waiver id '$col1' (expected numeric id)" >&2
    exit 1
  fi

  if [[ -z "$col2" ]]; then
    echo "Error: line $LINE_NO: missing status for id $col1" >&2
    exit 1
  fi

  status="$(normalize_status "$col2")" || exit 1

  if [[ -n "$col3" ]]; then
    justification="$col3"
  elif [[ "$status" == "approved" ]]; then
    justification="$APPROVE_JUSTIFICATION"
  else
    justification="$REJECT_JUSTIFICATION"
  fi

  if [[ "$status" == "approved" ]]; then
    if [[ -n "$col4" ]]; then
      duration_days="$col4"
    else
      duration_days="$DURATION_DAYS"
    fi

    if [[ ! "$duration_days" =~ ^[0-9]+$ ]] || [[ "$duration_days" -lt 1 ]]; then
      echo "Error: line $LINE_NO: invalid duration_days '$duration_days' (expected positive integer)" >&2
      exit 1
    fi
  else
    duration_days=""
  fi

  payload="$(build_payload "$status" "$justification" "${duration_days:-0}")"

  TOTAL=$((TOTAL + 1))
  if [[ "$status" == "approved" ]]; then
    APPROVED=$((APPROVED + 1))
  else
    REJECTED=$((REJECTED + 1))
  fi

  if ! submit_decision "$col1" "$payload"; then
    FAILED=$((FAILED + 1))
  fi
done < "$INPUT_FILE"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "No waiver decisions found in '$INPUT_FILE'." >&2
  exit 1
fi

SUCCEEDED=$((TOTAL - FAILED))
if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry-run complete: $TOTAL request(s) ($APPROVED approve, $REJECTED reject)." >&2
else
  echo "Done: $SUCCEEDED/$TOTAL succeeded ($APPROVED approve, $REJECTED reject, $FAILED failed)." >&2
fi

[[ "$FAILED" -eq 0 ]]
