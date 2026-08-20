#!/usr/bin/env bash
#
# find-long-lived-tokens.sh
# List JFrog access tokens that are long-lived — either no expiry, or a
# validity period of 365 days or more (issued_at → expiry).
#
# Uses the Access API: GET /access/api/v1/tokens
# The bearer token must have admin scope (needed to list all tokens).
#
# Output (in current directory):
#   long_lived_tokens.csv
#     columns: username,token_id,issued_at,expiry,days_valid,description
#
# Usage:
#   ./find-long-lived-tokens.sh -u <artifactory-url> -t <bearer-token>
#

set -euo pipefail

ART_URL=""
TOKEN=""
OUT_CSV="long_lived_tokens.csv"
THRESHOLD_DAYS=365

# ---------- parse args -------------------------------------------------------
while getopts ":u:t:h" opt; do
    case "$opt" in
        u) ART_URL="$OPTARG" ;;
        t) TOKEN="$OPTARG" ;;
        h) echo "Usage: $0 -u <artifactory-url> -t <bearer-token>"; exit 0 ;;
       \?) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
    esac
done

if [[ -z "$ART_URL" || -z "$TOKEN" ]]; then
    echo "Usage: $0 -u <artifactory-url> -t <bearer-token>" >&2
    exit 1
fi

# Normalize: strip trailing slash, ensure /artifactory suffix
ART_URL="${ART_URL%/}"
[[ "$ART_URL" != */artifactory ]] && ART_URL="${ART_URL}/artifactory"

# The Access API lives under /access, sibling of /artifactory on the same host
BASE_URL="${ART_URL%/artifactory}"

# ---------- functions --------------------------------------------------------

# Fetch all access tokens from the Access API.
fetch_tokens() {
    echo "Fetching access tokens from $BASE_URL/access/api/v1/tokens ..."
    curl -s -H "Authorization: Bearer $TOKEN" \
        "$BASE_URL/access/api/v1/tokens" \
      > /tmp/tokens_raw.json 2>/dev/null

    local count
    count=$(jq '.tokens | length' /tmp/tokens_raw.json 2>/dev/null)
    echo "Fetched ${count:-0} tokens total"
}

# Filter tokens: keep only those with no expiry OR validity >= 365 days.
# Extract username from subject (usually looks like ".../users/<username>").
filter_long_lived() {
    echo "Filtering long-lived tokens (>= ${THRESHOLD_DAYS} days or no expiry) ..."
    echo "username,token_id,issued_at,expiry,days_valid,description" > "$OUT_CSV"

    jq -r --argjson threshold "$THRESHOLD_DAYS" '
        .tokens[]
        | . as $t
        | ($t.expiry // 0)     as $exp
        | ($t.issued_at // 0)  as $iat
        | (if $exp == 0 then -1
           else (($exp - $iat) / 86400 | floor)
           end)                as $days
        | select($days == -1 or $days >= $threshold)
        | ($t.subject | split("/") | last) as $user
        | [ $user,
            $t.token_id,
            (if $iat == 0 then "" else ($iat | todate) end),
            (if $exp == 0 then "no-expiry" else ($exp | todate) end),
            (if $days == -1 then "no-expiry" else ($days | tostring) end),
            ($t.description // "") ]
        | @csv
    ' /tmp/tokens_raw.json 2>/dev/null >> "$OUT_CSV"

    local count
    count=$(( $(wc -l < "$OUT_CSV") - 1 ))
    echo "Found $count long-lived token(s). Report written to $OUT_CSV"
}

# ---------- main -------------------------------------------------------------
fetch_tokens
filter_long_lived