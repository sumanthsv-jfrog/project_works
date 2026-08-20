#!/usr/bin/env bash
#
# find-duplicate-remotes.sh
# List Artifactory remote repos and find ones sharing the same upstream URL.
#
# Outputs (in current directory):
#   remotes.csv     — all remote repos
#                     (repositoryname,url,packagetype,has_credentials,virtual_repos)
#   duplicates.txt  — repos grouped by shared upstream URL, showing credential
#                     status and which virtual repos aggregate each remote
#
# Usage:
#   ./find-duplicate-remotes.sh -u <artifactory-url> -t <bearer-token>
#

set -euo pipefail

ART_URL=""
TOKEN=""
REMOTES_CSV="remotes.csv"
DUPES_FILE="duplicates.txt"

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

# ---------- functions --------------------------------------------------------

# Fetch all remote repos in a single call to /api/repositories/configurations.
# Response is grouped by type: { "LOCAL": [...], "REMOTE": [...], "VIRTUAL": [...], ... }.
# For each remote we also compute the list of virtual repos that aggregate it
# (a virtual repo's 'repositories' array lists its member repo keys).
fetch_remotes() {
    echo "Fetching remote repository details from $ART_URL ..."
    echo "repositoryname,url,packagetype,has_credentials,virtual_repos" > "$REMOTES_CSV"
#    curl -s -H "Authorization: Bearer $TOKEN" \
#        "$ART_URL/api/repositories/configurations" 2>/dev/null \
      cat consoleText.txt |  jq -r ' 
          . as $root
          | $root.REMOTE[]
          | .key as $rkey
          | ( $root.VIRTUAL // []
              | map(select((.repositories // []) | index($rkey)) | .key)
              | join(";")
            ) as $vlist
          | [ $rkey,
              .url,
              .packageType,
              (if ((.username // "") | length) > 0 then "yes" else "no" end),
              (if $vlist == "" then "none" else $vlist end)
            ]
          | @csv
        ' 2>/dev/null \
      >> "$REMOTES_CSV"

    local count
    count=$(( $(wc -l < "$REMOTES_CSV") - 1 ))
    echo "Saved $count remote repositories to $REMOTES_CSV"
}

# Find URLs used by 2+ repos and write a grouped text report.
find_duplicates() {
    echo "Checking for duplicate upstream URLs ..."

    # URLs that appear more than once (skip header, column 2)
    local dup_urls
    dup_urls=$(tail -n +2 "$REMOTES_CSV" | awk -F',' '{print $2}' | sort | uniq -d)

    : > "$DUPES_FILE"

    if [[ -z "$dup_urls" ]]; then
        echo "No duplicate upstream URLs found." > "$DUPES_FILE"
        echo "No duplicates. Report written to $DUPES_FILE"
        return
    fi

    # For each duplicate URL, write a group: header + matching repos
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        {
            echo "URL: ${url//\"/}"
            awk -F',' -v u="$url" 'NR>1 && $2==u {
                gsub(/"/, "", $1); gsub(/"/, "", $3); gsub(/"/, "", $4); gsub(/"/, "", $5)
                printf "  %s  (%s)  [credentials: %s]  [in virtuals: %s]\n", $1, $3, $4, $5
            }' "$REMOTES_CSV"
            echo
        } >> "$DUPES_FILE"
    done <<< "$dup_urls"

    local group_count
    group_count=$(echo "$dup_urls" | grep -c .)
    echo "Found $group_count duplicate URL group(s). Report written to $DUPES_FILE"
}

# ---------- main -------------------------------------------------------------
fetch_remotes
find_duplicates
