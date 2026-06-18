#!/bin/bash

# ============================================================
#  JFrog - List LOCAL repos with created date -> CSV output
#  Source: api/storageinfo + api/storage/<repo>
#  Output: repoName, repoType, packageType, usedSpace, createdDate, age
#  Dependencies: curl, jq
# ============================================================

ARTIFACTORY_URL="https://test.jfrog.io/artifactory"
TOKEN="update-token-here"

# Colours
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}   JFrog Local Repository Report                           ${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# --- Ask user for optional age filter ---
echo -e "${BOLD}Filter by age (optional):${NC}"
echo -e "  Enter the number of years to filter repos older than that age."
echo -e "  Press ${YELLOW}Enter${NC} to skip and generate the full report only."
echo ""
read -rp "  How many years old? (e.g. 6, or press Enter to skip): " YEARS_INPUT
echo ""

FILTER_YEARS=""
if [[ "$YEARS_INPUT" =~ ^[0-9]+$ ]]; then
  FILTER_YEARS="$YEARS_INPUT"
  echo -e "${CYAN}  ✔ Will also generate a filtered report for repos older than ${FILTER_YEARS} year(s).${NC}"
else
  echo -e "${CYAN}  ✔ No age filter applied. Generating full report only.${NC}"
fi
echo ""

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_CSV="jfrog_local_repos_${TIMESTAMP}.csv"
FILTERED_CSV="jfrog_local_repos_older_than_${FILTER_YEARS}yrs_${TIMESTAMP}.csv"

# Step 1: Fetch storageinfo
echo -e "${YELLOW}⏳ Fetching storage info from Artifactory... please wait.${NC}"
echo ""

STORAGEINFO_RAW=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${ARTIFACTORY_URL}/api/storageinfo")

HTTP_STATUS=$(echo "$STORAGEINFO_RAW" | grep "HTTP_STATUS:" | cut -d: -f2)
STORAGEINFO=$(echo "$STORAGEINFO_RAW" | grep -v "HTTP_STATUS:")

if [ -z "$STORAGEINFO" ]; then
  echo -e "${RED}ERROR: Empty response from Artifactory (HTTP ${HTTP_STATUS}).${NC}"
  echo -e "${YELLOW}Check your TOKEN and ARTIFACTORY_URL are set correctly.${NC}"
  exit 1
fi

if echo "$STORAGEINFO" | grep -q '"errors"'; then
  echo -e "${RED}ERROR: Artifactory returned an error (HTTP ${HTTP_STATUS}):${NC}"
  echo "$STORAGEINFO"
  exit 1
fi

echo -e "${CYAN}  ✔ Storage info fetched successfully (HTTP ${HTTP_STATUS}).${NC}"
echo ""

# Step 2: Extract LOCAL repos using jq -> TSV (repoKey, repoType, packageType, usedSpace)
LOCAL_REPOS=$(echo "$STORAGEINFO" | jq -r '
  .repositoriesSummaryList[]
  | select(.repoKey != "TOTAL" and .repoType == "LOCAL")
  | [.repoKey, .repoType, .packageType, .usedSpace, .filesCount]
  | @tsv
')

if [ -z "$LOCAL_REPOS" ]; then
  echo -e "${YELLOW}No LOCAL repositories found.${NC}"
  exit 0
fi

TOTAL=$(echo "$LOCAL_REPOS" | wc -l | tr -d ' ')
echo -e "${CYAN}Found ${TOTAL} LOCAL repositories. Fetching creation dates...${NC}"
echo ""

# Step 3: Write CSV headers
echo "Repo Name,Repo Type,Package Type,Used Space,Artifact Count,Created Date,Age (Years)" > "$OUTPUT_CSV"
if [ -n "$FILTER_YEARS" ]; then
  echo "Repo Name,Repo Type,Package Type,Used Space,Artifact Count,Created Date,Age (Years)" > "$FILTERED_CSV"
fi

# Step 4: Loop through each repo and get created date
COUNT=0
FILTERED_COUNT=0
NOW_EPOCH=$(date +%s)

while IFS=$'\t' read -r REPO_KEY REPO_TYPE PKG_TYPE USED_SPACE ARTIFACT_COUNT; do
  COUNT=$((COUNT + 1))

  printf "${YELLOW}  [%s/%s] Fetching details for: %-60s${NC}\r" "$COUNT" "$TOTAL" "$REPO_KEY"

  STORAGE_JSON=$(curl -s \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${ARTIFACTORY_URL}/api/storage/${REPO_KEY}")

  # Parse created date using jq + shell date (no python)
  CREATED_RAW=$(echo "$STORAGE_JSON" | jq -r '.created // "N/A"')

  if [ "$CREATED_RAW" != "N/A" ] && [ -n "$CREATED_RAW" ]; then
    CREATED_TRIM="${CREATED_RAW%.*}"   # strip milliseconds

    # macOS: date -j  |  Linux: date -d
    CREATED_HUMAN=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED_TRIM" "+%B %d, %Y  %I:%M %p UTC" 2>/dev/null \
      || date -d "$CREATED_RAW" "+%B %d, %Y  %I:%M %p UTC" 2>/dev/null \
      || echo "$CREATED_RAW")

    CREATED_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED_TRIM" "+%s" 2>/dev/null \
      || date -d "$CREATED_RAW" "+%s" 2>/dev/null \
      || echo "0")

    AGE_YEARS=$(( (NOW_EPOCH - CREATED_EPOCH) / 31536000 ))
  else
    CREATED_HUMAN="N/A"
    AGE_YEARS=0
  fi

  sleep 3

  # Append to full CSV
  echo "\"${REPO_KEY}\",\"${REPO_TYPE}\",\"${PKG_TYPE}\",\"${USED_SPACE}\",\"${ARTIFACT_COUNT}\",\"${CREATED_HUMAN}\",\"${AGE_YEARS}\"" >> "$OUTPUT_CSV"

  # Append to filtered CSV if age qualifies
  if [ -n "$FILTER_YEARS" ] && [ "$AGE_YEARS" -ge "$FILTER_YEARS" ] 2>/dev/null; then
    echo "\"${REPO_KEY}\",\"${REPO_TYPE}\",\"${PKG_TYPE}\",\"${USED_SPACE}\",\"${ARTIFACT_COUNT}\",\"${CREATED_HUMAN}\",\"${AGE_YEARS}\"" >> "$FILTERED_CSV"
    FILTERED_COUNT=$((FILTERED_COUNT + 1))
  fi

done <<< "$LOCAL_REPOS"

# Clear progress line
printf "\033[2K\r"

echo -e "${GREEN} Full report saved to     : ${OUTPUT_CSV}${NC}"
echo -e "${CYAN}   Total repos processed    : ${TOTAL}${NC}"

if [ -n "$FILTER_YEARS" ]; then
  echo ""
  echo -e "${GREEN} Filtered report saved to : ${FILTERED_CSV}${NC}"
  echo -e "${CYAN}   Repos older than ${FILTER_YEARS} year(s) : ${FILTERED_COUNT}${NC}"
fi

echo ""

# ============================================================
#  Step 5: Generate Package Type Summary Report from CSV
# ============================================================

SUMMARY_CSV="jfrog_packagetype_summary_${TIMESTAMP}.csv"

echo -e "${YELLOW} Generating package type summary report...${NC}"

echo "Package Type,Repo Name,Used Space,Artifact Count" > "$SUMMARY_CSV"

# Read full CSV (skip header), sort by package type, write grouped rows
tail -n +2 "$OUTPUT_CSV" \
  | sort -t',' -k3,3 \
  | while IFS=',' read -r RKEY RTYPE RPKG RSPACE RCOUNT RCREATED RAGE; do
      RPKG_CLEAN=$(echo "$RPKG"     | tr -d '"')
      RKEY_CLEAN=$(echo "$RKEY"     | tr -d '"')
      RSPACE_CLEAN=$(echo "$RSPACE" | tr -d '"')
      RCOUNT_CLEAN=$(echo "$RCOUNT" | tr -d '"')
      echo "\"${RPKG_CLEAN}\",\"${RKEY_CLEAN}\",\"${RSPACE_CLEAN}\",\"${RCOUNT_CLEAN}\""
    done >> "$SUMMARY_CSV"

# Print breakdown to terminal with repo count + total size per package type
echo ""
echo -e "${CYAN}  Package Type Breakdown:${NC}"
printf "  %-25s %-10s %-15s %s\n" "Package Type" "Repos" "Artifacts" "Total Size"
echo "  ----------------------------------------------------------------"

tail -n +2 "$OUTPUT_CSV" | tr -d '"' | awk -F',' '
{
  pkg = $3
  space = $4
  artifacts = $5
  repocount[pkg]++
  artifacttotal[pkg] += artifacts

  # Parse numeric value and unit separately to avoid integer overflow
  # Store totals in GB (float) to safely handle TB-scale repos
  num = space + 0

  if      (index(space,"TB") > 0) val_gb = num * 1024
  else if (index(space,"GB") > 0) val_gb = num
  else if (index(space,"MB") > 0) val_gb = num / 1024
  else if (index(space,"KB") > 0) val_gb = num / 1048576
  else                            val_gb = num / 1073741824

  total_gb[pkg] += val_gb
}
END {
  for (pkg in repocount) {
    t = total_gb[pkg]
    if      (t >= 1024)   human = sprintf("%.2f TB", t / 1024)
    else if (t >= 1)      human = sprintf("%.2f GB", t)
    else if (t >= 0.001)  human = sprintf("%.2f MB", t * 1024)
    else                  human = sprintf("%.2f KB", t * 1048576)
    printf "  %-25s %-10s %-15s %s\n", pkg, repocount[pkg], artifacttotal[pkg], human
  }
}
' | sort

echo "  ----------------------------------------------------------------"
echo ""
echo -e "${GREEN}Package type summary saved to: ${SUMMARY_CSV}${NC}"
echo ""
