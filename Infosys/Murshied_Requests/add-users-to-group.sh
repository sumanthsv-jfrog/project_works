#!/usr/bin/env bash
#
# add-users-to-group.sh
# Add users listed in a file to a JFrog Artifactory group.
#
# Validation flow:
#   1. Verify the target group exists (single API call).
#   2. Fetch all users in one API call and build an in-memory set.
#   3. For each username in the input file:
#        - Check membership against the set (no per-user API call).
#        - If found, add them to the group (preserving existing groups).
#        - If not, log as not-found and move on.
#
# Inputs:
#   -u  Artifactory base URL  (/artifactory auto-appended if missing)
#   -t  Bearer token          (admin scope required)
#   -f  File with usernames   (one per line; blank lines and '#' comments ignored)
#   -g  Target group name
#
# Output (in current directory):
#   add_users_result.csv      columns: username,status,message
#
# Usage:
#   ./add-users-to-group.sh -u https://psblr.jfrog.io -t "$JF_TOKEN" \
#                           -f users.txt -g developers
#

set -euo pipefail

ART_URL=""
TOKEN=""
USER_FILE=""
GROUP=""
LOG_CSV="add_users_result.csv"
ALL_USERS_JSON="/tmp/all_users.json"
USER_DETAIL_JSON="/tmp/user_detail.json"

# ---------- parse args -------------------------------------------------------
while getopts ":u:t:f:g:h" opt; do
    case "$opt" in
        u) ART_URL="$OPTARG" ;;
        t) TOKEN="$OPTARG" ;;
        f) USER_FILE="$OPTARG" ;;
        g) GROUP="$OPTARG" ;;
        h) echo "Usage: $0 -u <url> -t <token> -f <users-file> -g <group>"; exit 0 ;;
       \?) echo "Unknown option: -$OPTARG" >&2; exit 1 ;;
    esac
done

if [[ -z "$ART_URL" || -z "$TOKEN" || -z "$USER_FILE" || -z "$GROUP" ]]; then
    echo "Usage: $0 -u <url> -t <token> -f <users-file> -g <group>" >&2
    exit 1
fi

if [[ ! -f "$USER_FILE" ]]; then
    echo "ERROR: user file not found: $USER_FILE" >&2
    exit 1
fi

# Normalize URL
ART_URL="${ART_URL%/}"
[[ "$ART_URL" != */artifactory ]] && ART_URL="${ART_URL}/artifactory"

# ---------- helpers ----------------------------------------------------------

# Generic HTTP call. Body written to $2, echoes HTTP status code to stdout.
art_call() {
    local method="$1" out_file="$2" path="$3" data="${4:-}"
    if [[ -n "$data" ]]; then
        curl -s -o "$out_file" -w "%{http_code}" \
             -X "$method" \
             -H "Authorization: Bearer $TOKEN" \
             -H "Content-Type: application/json" \
             -d "$data" \
             "$ART_URL$path" 2>/dev/null
    else
        curl -s -o "$out_file" -w "%{http_code}" \
             -X "$method" \
             -H "Authorization: Bearer $TOKEN" \
             "$ART_URL$path" 2>/dev/null
    fi
}

# ---------- functions --------------------------------------------------------

# Step 1: abort if the target group doesn't exist.
check_group_exists() {
    echo "Verifying group '$GROUP' exists ..."
    local code
    code=$(art_call GET /tmp/group_check.json "/api/security/groups/$GROUP")
    if [[ "$code" != "200" ]]; then
        echo "ERROR: group '$GROUP' not found " >&2
        exit 1
    fi
    echo "Group '$GROUP' exists."
}

# Step 2: fetch all users in a single call. Stores full response for lookups.
fetch_all_users() {
    echo "Fetching all users ..."
    local code
    code=$(art_call GET "$ALL_USERS_JSON" "/api/security/users")
    if [[ "$code" != "200" ]]; then
        echo "ERROR: could not list users (HTTP $code)" >&2
        exit 1
    fi
    local count
    count=$(jq 'length' "$ALL_USERS_JSON" 2>/dev/null || echo 0)
    echo "Fetched ${count:-0} users."
}

# Check if a username exists in the fetched user list (no API call).
user_exists() {
    local username="$1"
    jq -e --arg u "$username" 'any(.[]; .name == $u)' "$ALL_USERS_JSON" >/dev/null 2>&1
}

# Add $GROUP to a user's group list, preserving existing memberships.
# Echoes one of: added | already-member | error-http-<code>
add_user_to_group() {
    local username="$1"

    # Get current groups (need this per-user; the bulk list doesn't include them)
    local code
    code=$(art_call GET "$USER_DETAIL_JSON" "/api/security/users/$username")
    if [[ "$code" != "200" ]]; then
        echo "error-http-$code"
        return
    fi

    # Already a member? — check locally
    if jq -e --arg g "$GROUP" '(.groups // []) | index($g)' "$USER_DETAIL_JSON" >/dev/null 2>&1; then
        echo "already-member"
        return
    fi

    # Merge and POST update
    local body
    body=$(jq -c --arg g "$GROUP" '{groups: ((.groups // []) + [$g] | unique)}' "$USER_DETAIL_JSON")

    code=$(art_call POST /dev/null "/api/security/users/$username" "$body")
    if [[ "$code" == "200" || "$code" == "201" ]]; then
        echo "added"
    else
        echo "error-http-$code"
    fi
}

# Step 3: iterate input file, act on each user, write CSV log.
process_users() {
    echo "Processing users from $USER_FILE ..."
    echo "username,status,message" > "$LOG_CSV"

    local total=0 added=0 skipped=0 missing=0 failed=0

    while IFS= read -r username || [[ -n "$username" ]]; do
        # Trim + skip blanks/comments
        username="${username#"${username%%[![:space:]]*}"}"
        username="${username%"${username##*[![:space:]]}"}"
        [[ -z "$username" || "$username" == \#* ]] && continue

        total=$((total + 1))

        if ! user_exists "$username"; then
            printf '"%s","not-found","user does not exist"\n' "$username" >> "$LOG_CSV"
            missing=$((missing + 1))
            continue
        fi

        local result
        result=$(add_user_to_group "$username")
        case "$result" in
            added)
                printf '"%s","added","added to group %s"\n' "$username" "$GROUP" >> "$LOG_CSV"
                added=$((added + 1))
                ;;
            already-member)
                printf '"%s","skipped","already member of %s"\n' "$username" "$GROUP" >> "$LOG_CSV"
                skipped=$((skipped + 1))
                ;;
            *)
                printf '"%s","error","%s"\n' "$username" "$result" >> "$LOG_CSV"
                failed=$((failed + 1))
                ;;
        esac
    done < "$USER_FILE"

    echo "Processed $total user(s): $added added, $skipped already-member, $missing not-found, $failed failed"
    echo "Report written to $LOG_CSV"
}

# ---------- main -------------------------------------------------------------
check_group_exists
fetch_all_users
process_users
