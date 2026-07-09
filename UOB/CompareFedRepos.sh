#!/bin/bash

# =========================================================
# JFrog Federated Repository Storage Comparison Script
# =========================================================

JPD_A_URL="${1:?ERROR: Please provide JPD A URL (e.g., https://jpd-primary.jfrog.io) as the first argument.}"
JPD_B_URL="${2:?ERROR: Please provide JPD B URL (e.g., https://jpd-dr.jfrog.io) as the second argument.}"
USER_NAME="${3:?ERROR: Please provide the Username (e.g., admin) as the third argument.}"
JPD_AUTH_TOKEN="${4:?ERROR: Please provide the Access Token as the third argument.}"
AUTH="${USER_NAME}:${JPD_AUTH_TOKEN}"

# Set Output Filenames
STORAGE_A_FILE="jpd_a_storageinfo.json"
STORAGE_B_FILE="jpd_b_storageinfo.json"
OUTPUT_CSV="federated_repos_comparison.csv"

echo "Fetching storage info from JPD A: ${JPD_A_URL}..."
curl -s -u "$AUTH" "${JPD_A_URL}/artifactory/api/storageinfo" -o "$STORAGE_A_FILE"
if [ $? -ne 0 ]; then echo "Error fetching data from JPD A. Exiting."; exit 1; fi

echo "Fetching storage info from JPD B: ${JPD_B_URL}..."
curl -s -u "$AUTH" "${JPD_B_URL}/artifactory/api/storageinfo" -o "$STORAGE_B_FILE"
if [ $? -ne 0 ]; then echo "Error fetching data from JPD B. Exiting."; exit 1; fi

# ====================================
echo "Creating comparison report: ${OUTPUT_CSV}"
echo "RepoName,FilesCount_A,UsedSpace_A,FilesCount_B,UsedSpace_B" > "$OUTPUT_CSV"

# Extract only FEDERATED repos from JPD A to drive the comparison
jq -r '.repositoriesSummaryList[] | select(.repoType=="FEDERATED") | .repoKey' "$STORAGE_A_FILE" | while read -r repo; do

    # Get repo data from JPD A
    filesA=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .filesCount' "$STORAGE_A_FILE")
    sizeA=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .usedSpace' "$STORAGE_A_FILE")

    # Get repo data from JPD B (handles case where repo might not exist in B)
    # 2>/dev/null suppresses errors if jq can't find the repo in B's file.
    filesB=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .filesCount' "$STORAGE_B_FILE" 2>/dev/null)
    sizeB=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .usedSpace' "$STORAGE_B_FILE" 2>/dev/null)

    # Write to CSV, using 0 and N/A as defaults if data is missing from B
    echo "${repo},${filesA:-0},${sizeA:-N/A},${filesB:-0},${sizeB:-N/A}" >> "$OUTPUT_CSV"

done

# ================================
# ======= DISPLAY SUMMARY =======
# ================================
echo
echo "Federated repo comparison complete! Results are in: ${OUTPUT_CSV}"
echo "---"
column -t -s ',' "$OUTPUT_CSV"
echo "---"

# --- Cleanup temporary files ---
rm -f "$STORAGE_A_FILE" "$STORAGE_B_FILE"
echo "Cleaned up temporary JSON files."
