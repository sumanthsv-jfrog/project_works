#!/usr/bin/env bash
# Run command sed 's/^[^{]*//' storage_file_downloade.txt| tr "'" '"' 
# Build CSV reports from a JFrog storage-summary file (one object per line).
#
#   repos_detail.csv      projectKey,repoKey,packageType,size,sizeBytes
#   projects_summary.csv  projectKey,repos,totalSize,totalSizeBytes
#
# Tolerant: lines that don't parse as JSON are skipped (not fatal).
#
# Usage:
#   ./jfrog_report.sh storage_summary.json
#
set -uo pipefail

FILE="${1:-storage_summary.json}"
DETAIL="repos_detail.csv"
SUMMARY="projects_summary.csv"

[[ -f "$FILE" ]] || { echo "Error: file not found: $FILE" >&2; exit 1; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# --- extract one TSV row per repo, skipping any unparseable line ---
skipped=0
while IFS= read -r line; do
    [[ "$line" == *"{"* ]] || continue
    json="{${line#*\{}"                       # keep from first '{'
    out="$(printf '%s\n' "$json" | jq -r '
        .repositoriesSummaryList[]?
        | [.projectKey, .repoKey, .packageType, .usedSpace,
           (.usedSpaceInBytes // 0)] | @tsv' 2>/dev/null)"
    if [[ -z "$out" && -n "${line// }" ]]; then
        skipped=$((skipped+1)); continue
    fi
    [[ -n "$out" ]] && printf '%s\n' "$out" >> "$TMP"
done < "$FILE"

(( skipped > 0 )) && echo "  ($skipped line(s) skipped)" >&2

# --- detail CSV: one row per repo, sorted by projectKey then size desc ---
{
    echo "projectKey,repoKey,packageType,size,sizeBytes"
    sort -t$'\t' -k1,1 -k5,5rn "$TMP" \
      | awk -F'\t' '{ printf "\"%s\",\"%s\",\"%s\",\"%s\",%s\n",$1,$2,$3,$4,$5 }'
} > "$DETAIL"

# --- summary CSV: aggregate per projectKey, sorted by total size desc ---
{
    echo "projectKey,repos,totalSize,totalSizeBytes"
    awk -F'\t' '
        function human(b,   arr,i){
            split("bytes KB MB GB TB PB",arr," "); i=1
            while (b>=1024 && i<6){ b=b/1024; i++ }
            if (i==1) return int(b)" bytes"
            return sprintf("%.2f %s",b,arr[i])
        }
        { cnt[$1]++; sum[$1]+=$5 }
        END { for (k in sum) printf "%s\t%d\t%s\t%.0f\n",k,cnt[k],human(sum[k]),sum[k] }
    ' "$TMP" \
      | sort -t$'\t' -k4,4rn \
      | awk -F'\t' '{ printf "\"%s\",%s,\"%s\",%s\n",$1,$2,$3,$4 }'
} > "$SUMMARY"

repos=$(wc -l < "$TMP" | tr -d ' ')
keys=$(cut -f1 "$TMP" | sort -u | wc -l | tr -d ' ')
echo "Wrote $DETAIL ($repos repos) and $SUMMARY ($keys project keys)."
