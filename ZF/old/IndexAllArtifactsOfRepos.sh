#!/bin/bash

ARTIFACTORY_URL="${1:?Error: ARTIFACTORY_URL is required. ex: https://mycompany.jfrog.io/artifactory}"
ACCESS_TOKEN="${2:?Error: ACCESS_TOKEN is required.}"
repostoindex="${3:?Error: REPO_LIST_FILE is required. ex: repos.txt}"
MAX_REPOS=5

indexreposfile=not_fully_indexed.csv
statusfile=redirectfile.csv

echo "reponame,completed,potential,percentage" > $statusfile

usage() {
  echo ""
  echo "Usage:"
  echo "  $0 <ARTIFACTORY_URL> <ACCESS_TOKEN> <REPO_LIST_FILE>"
  echo ""
  echo "Mandatory:"
  echo "  ARTIFACTORY_URL   Base Artifactory URL (example: https://mycompany.jfrog.io/artifactory)"
  echo "  ACCESS_TOKEN      JFrog Access Token"
  echo "  REPO_LIST_FILE    File containing repository names (one per line)"
  echo ""
  echo "Notes:"
  echo "  • Repos with index < 100% will be indexed."
  echo "  • Indexing may take significant time depending on repo size and artifact count."
  echo "  • Avoid running against a large number of repositories at once."
  echo ""
  echo "Examples:"
  echo "  $0 https://mycompany.jfrog.io/artifactory \$TOKEN repos.txt"
  echo "  $0 https://mycompany.jfrog.io/artifactory \$TOKEN repos_not_fully_indexed.csv"
  echo ""
  exit 1
}

GetIndexStatusOfRepos() {
  echo " Fetching index status of repos..."

  for repo in $(cat "$repostoindex"); do
    echo "\tChecking: $repo"
    response=$(curl -s -XPOST \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"repo_key\":\"$repo\"}" \
      "$ARTIFACTORY_URL/xray/ui/unified/stats/indexStatus")
    completed=$(echo "$response" | jq -r '.completed // 0')
    potential=$(echo "$response" | jq -r '.potential // 0')
    if [[ "$potential" -gt 0 ]]; then
      percentage=$(awk "BEGIN { printf \"%d\", (($completed/$potential)*100) }")
    else
      percentage="0"
    fi
    echo "$repo,$completed,$potential,$percentage" >> "$statusfile"
  done
}

GetNotFullyIndexedRepos() {
  awk -F',' 'NR>1 && $4 != 100 { print $1 }' "$statusfile" > "$indexreposfile"

  count=$(wc -l < "$indexreposfile" | tr -d ' ')
  echo " Found $count repo(s) with index < 100% → saved to: $indexreposfile"
}

EnableIndexing() {
  if [[ ! -s "$indexreposfile" ]]; then
    echo " No repos with index < 100%. Nothing to index."
    return
  fi

  for repo in $(cat "$indexreposfile"); do
    echo " Indexing: $repo"
    curl -s -XPOST \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      "$ARTIFACTORY_URL/xray/api/v1/index/repository/$repo"
    echo ""
  done
}

Action() {
  if [[ ! -f "$repostoindex" ]]; then
    echo " Error: file '$repostoindex' not found."
    exit 1
  fi

  repo_count=$(wc -l < "$repostoindex" | tr -d ' ')
  if [[ "$repo_count" -gt "$MAX_REPOS" ]]; then
    echo " Error: '$repostoindex' contains $repo_count repos, exceeding the limit of $MAX_REPOS (MAX_REPOS)."
    echo "Split the file into smaller batches and re-run."
    exit 1
  fi
 
  echo " Repo count: $repo_count / $MAX_REPOS — OK"
  
  GetIndexStatusOfRepos
  GetNotFullyIndexedRepos
  EnableIndexing
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

Action
