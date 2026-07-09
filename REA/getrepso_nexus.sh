#!/usr/bin/env bash
#
# Reports per-repository size and asset count for all Nexus repositories
# by summing the fileSize of every asset (paginated via continuationToken).
#
# Usage:
#   export NEXUS_PASSWORD='your-admin-password'
#   ./nexus-repo-sizes.sh            # all repos
#   ./nexus-repo-sizes.sh 'sum-*'    # only repos matching a glob
#
set -euo pipefail

NEXUS="${NEXUS:-http://172.18.98.95:8081}"
USER="${NEXUS_USER:-admin}"
PASS="${NEXUS_PASSWORD:-1Q2w3e4r}"
AUTH="$USER:$PASS"
API="$NEXUS/service/rest/v1"
FILTER="${1:-*}"

command -v jq >/dev/null || { echo "jq is required (brew install jq)"; exit 1; }

human() {  # bytes -> human readable
  awk -v b="$1" 'BEGIN{
    split("B KB MB GB TB",u," "); i=1;
    while(b>=1024 && i<5){b/=1024;i++}
    printf (i==1?"%d %s":"%.2f %s"), b, u[i]
  }'
}

# list repo names matching the filter
all_repos=$(curl -s -u "$AUTH" "$API/repositories" | jq -r '.[].name' | sort)
repos=""
for r in $all_repos; do
  case "$r" in
    $FILTER)
      repos="$repos $r"
      ;;
  esac
done

[ -z "$repos" ] && { echo "No repositories match '$FILTER'"; exit 0; }

printf "%-28s %12s %10s\n" "REPOSITORY" "SIZE" "ASSETS"
printf "%-28s %12s %10s\n" "----------" "----" "------"

grand_bytes=0; grand_assets=0
for repo in $repos; do
  bytes=0; assets=0; token=""
  while :; do
    url="$API/assets?repository=$repo"
    [ -n "$token" ] && url="$url&continuationToken=$token"
    resp=$(curl -s -u "$AUTH" "$url")
    # sum fileSize (null-safe) and count items this page
    page_bytes=$(echo "$resp" | jq '[.items[].fileSize // 0] | add // 0')
    page_count=$(echo "$resp" | jq '.items | length')
    bytes=$((bytes + page_bytes))
    assets=$((assets + page_count))
    token=$(echo "$resp" | jq -r '.continuationToken')
    [ "$token" = "null" ] || [ -z "$token" ] && break
  done
  printf "%-28s %12s %10d\n" "$repo" "$(human "$bytes")" "$assets"
  grand_bytes=$((grand_bytes + bytes))
  grand_assets=$((grand_assets + assets))
done

printf "%-28s %12s %10s\n" "----------" "----" "------"
printf "%-28s %12s %10d\n" "TOTAL" "$(human "$grand_bytes")" "$grand_assets"