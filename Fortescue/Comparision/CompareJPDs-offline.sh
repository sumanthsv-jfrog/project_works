#!/bin/bash

###Declaring variables
JPD_A_URL="${1%/}"
JPD_B_URL="${2%/}"
SOURCE_AUTH_TOKEN="$3"
TARGET_AUTH_TOKEN="$4"
WEB_OUTPUT="${5:-no}"

STORAGE_A_FILE="jpd_a_storageinfo.json"
STORAGE_B_FILE="jpd_b_storageinfo.json"

REPOCONFIG_A_FILE="jpd_a_repoconfig.json"
REPOCONFIG_B_FILE="jpd_b_repoconfig.json"

OUTPUT_LOCAL_CSV="local_repos_comparison.csv"
ONLY_IN_SOURCE_LOCAL="only_in_source_local.csv"
ONLY_IN_TARGET_LOCAL="only_in_target_local.csv"

OUTPUT_REMOTE_CSV="remote_repos_comparison.csv"
ONLY_IN_SOURCE_REMOTE="only_in_source_remote.csv"
ONLY_IN_TARGET_REMOTE="only_in_target_remote.csv"
OUTPUT_REMOTE_CONFIG_CSV="remote_repos_config_comparison.csv"
ONLY_IN_TARGET_REMOTE_CONFIG="only_in_target_remote_config.csv"

OUTPUT_VIRTUAL_CSV="virtual_repos_comparison.csv"
ONLY_IN_SOURCE_VIRTUAL="only_in_source_virtual.csv"
ONLY_IN_TARGET_VIRTUAL="only_in_target_virtual.csv"
OUTPUT_VIRTUAL_CONFIG_CSV="virtual_repos_config_comparison.csv"
ONLY_IN_TARGET_VIRTUAL_CONFIG="only_in_target_virtual_config.csv"

USERS_A_FILE="jpd_a_users.json"
USERS_B_FILE="jpd_b_users.json"
OUTPUT_USERS_CSV="users_comparison.csv"
ONLY_IN_SOURCE_USERS="only_in_source_users.csv"
ONLY_IN_TARGET_USERS="only_in_target_users.csv"

GROUPS_A_FILE="jpd_a_groups.json"
GROUPS_B_FILE="jpd_b_groups.json"
OUTPUT_GROUPS_CSV="groups_comparison.csv"
ONLY_IN_SOURCE_GROUPS="only_in_source_groups.csv"
ONLY_IN_TARGET_GROUPS="only_in_target_groups.csv"

PERMISSIONS_A_FILE="jpd_a_permissions.json"
PERMISSIONS_B_FILE="jpd_b_permissions.json"
OUTPUT_PERMISSIONS_CSV="permissions_comparison.csv"
ONLY_IN_SOURCE_PERMISSIONS="only_in_source_permissions.csv"
ONLY_IN_TARGET_PERMISSIONS="only_in_target_permissions.csv"

TOKENS_A_FILE="jpd_a_tokens.json"
TOKENS_B_FILE="jpd_b_tokens.json"
OUTPUT_TOKENS_CSV="tokens_comparison.csv"

#####Functions
usage() {
    echo "Usage: $0 <JPD_A_URL> <JPD_B_URL> <SOURCE_TOKEN> <TARGET_TOKEN> [weboutput]"
    echo ""
    echo "Arguments:"
    echo "  JPD_A_URL      URL of the Source Artifactory (e.g., https://source.jfrog.io)"
    echo "  JPD_B_URL      URL of the Target Artifactory (e.g., https://target.jfrog.io)"
    echo "  SOURCE_TOKEN   Admin-scoped Access Token for Source JPD (sent as Bearer auth)"
    echo "  TARGET_TOKEN   Admin-scoped Access Token for Target JPD (sent as Bearer auth)"
    echo "  weboutput      (Optional) Set to 'yes' to launch the HTML dashboard (default: no)"
    echo ""
    echo "Requirements:"
    echo "  - jq:       Required for JSON parsing."
    echo "  - python3:  Mandatory if using 'weboutput=yes' (to serve the dashboard)."
    echo ""
    echo "Example:"
    echo "  $0 \"https://src.io\" \"https://tgt.io\" \"cmVmdG...\" \"YWJj...\" \"yes\""
    exit 1
}

# Check if at least 4 arguments are provided
if [ "$#" -lt 4 ]; then
    usage
fi

## The Access API's users/groups/permissions LIST endpoints are paginated: the response
## includes a "cursor" value (the resume point - observed in practice to be the last item's
## name) which must be echoed back as a ?cursor= query param to fetch the next page. A single
## unpaginated fetch will silently truncate any instance with more entries than fit on one
## page, so every call to these three endpoints goes through this loop instead of a plain curl.
FetchPaginated()
{
# $1=url (may already include query params, e.g. "...?limit=120000")  $2=token
# $3=output file (final merged JSON written here)  $4=wrapper key ("users"/"groups"/"permissions")
local url="$1"
local token="$2"
local outfile="$3"
local key="$4"
local pagesfile="${outfile}.pages.jsonl"
local pagefile="${outfile}.page.json"
local cursor=""
local prevCursor=""
local pagecount=0

rm -f "$pagesfile" "$pagefile"

while true; do
    if [ -z "$cursor" ]; then
        curl -s -H "Authorization: Bearer ${token}" "$url" -o "$pagefile"
    else
        curl -s -G --data-urlencode "cursor=${cursor}" -H "Authorization: Bearer ${token}" "$url" -o "$pagefile"
    fi

    cat "$pagefile" >> "$pagesfile"
    echo >> "$pagesfile"

    local itemCount
    itemCount=$(jq -r --arg key "$key" '(.[$key] // []) | length' "$pagefile" 2>/dev/null)
    cursor=$(jq -r '.cursor // empty' "$pagefile" 2>/dev/null)
    pagecount=$((pagecount + 1))

    if [ -z "$cursor" ] || [ "$itemCount" == "0" ] || [ "$itemCount" == "null" ] || [ "$cursor" == "$prevCursor" ]; then
        break
    fi
    if [ "$pagecount" -ge 200 ]; then
        echo "WARNING: stopped paginating '${key}' after 200 pages - results may be incomplete. ($url)"
        break
    fi
    prevCursor="$cursor"
done

jq -s --arg key "$key" 'reduce .[] as $p ({($key): []}; .[$key] += ($p[$key] // []))' "$pagesfile" > "$outfile" 2>/dev/null

rm -f "$pagesfile" "$pagefile"
}

## The Access API's documented sample responses for the LIST endpoints (as opposed to the
## single-item GET endpoints, which ARE well-documented) are inconsistent/unconfirmed across
## JFrog platform versions - some have reported the group/permission name coming back under a
## different key than expected. Rather than hardcode one field name and silently print "null"
## when it's wrong, these functions try several known candidates and fall back to a visibly
## obvious "UNKNOWN_FIELD" marker (instead of null/blank) so a mismatch is impossible to miss.
NormalizeUsersFile()
{
local file="$1"
local tmp="${file}.norm"
jq 'if (.users|type)=="array" then
      {users: [.users[] | {
        username: (.username // .name // .user_name // .userName // "UNKNOWN_FIELD"),
        status:   (.status   // "N/A"),
        realm:    (.realm    // "N/A")
      }]}
    else {users: []} end' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"
}

NormalizeGroupsFile()
{
local file="$1"
local tmp="${file}.norm"
jq 'if (.groups|type)=="array" then
      {groups: [.groups[] | {
        name: (.name // .group_name // .groupName // .groupKey // "UNKNOWN_FIELD")
      }]}
    else {groups: []} end' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"
}

NormalizePermissionsFile()
{
local file="$1"
local tmp="${file}.norm"
jq 'if (.permissions|type)=="array" then
      {permissions: [.permissions[] | {
        name: (.name // .permission_name // .permissionName // "UNKNOWN_FIELD")
      }]}
    else {permissions: []} end' "$file" > "$tmp" 2>/dev/null && mv "$tmp" "$file"
}

ValidateJPD()
{
# $1=label ("Source"/"Target")  $2=url  $3=token
local label="$1"
local url="$2"
local token="$3"
local timeout_args="--connect-timeout 10 --max-time 20"

# 1. Is the URL even reachable? (unauthenticated ping - works even with a bad/missing token)
local ping_code
ping_code=$(curl -s -o /dev/null -w "%{http_code}" $timeout_args "${url}/artifactory/api/system/ping")
local curl_exit=$?
if [ $curl_exit -ne 0 ]; then
    echo "  [FAIL] $label: could not reach '$url' (curl exit code $curl_exit - check the URL/DNS/network/SSL)."
    return 1
fi
if [ "$ping_code" != "200" ]; then
    echo "  [FAIL] $label: '$url' responded with HTTP $ping_code on ping. Check the URL points to a valid JPD."
    return 1
fi

# 2. Is the token valid against the Artifactory API? (this endpoint requires auth)
local version_code
version_code=$(curl -s -o /dev/null -w "%{http_code}" $timeout_args -H "Authorization: Bearer ${token}" "${url}/artifactory/api/system/version")
if [ "$version_code" == "401" ] || [ "$version_code" == "403" ]; then
    echo "  [FAIL] $label: token rejected by Artifactory API (HTTP $version_code). Check the token is correct, not expired, and not revoked."
    return 1
elif [ "$version_code" != "200" ]; then
    echo "  [FAIL] $label: Artifactory API returned unexpected HTTP $version_code while validating the token."
    return 1
fi

echo "  [OK]   $label: '$url' reachable, token valid for Artifactory API."
return 0
}

ValidateInputs()
{
echo "Validating connectivity and tokens for both JPDs..."
ValidateJPD "Source" "$JPD_A_URL" "$SOURCE_AUTH_TOKEN"
local srcStatus=$?
ValidateJPD "Target" "$JPD_B_URL" "$TARGET_AUTH_TOKEN"
local tgtStatus=$?

if [ $srcStatus -eq 1 ] || [ $tgtStatus -eq 1 ]; then
    echo ""
    echo "Validation failed - aborting before making any further API calls. Fix the URL/token issue above and re-run."
    exit 1
fi

echo "Validation passed. Proceeding with comparison..."
echo ""
}

GetSourceVersion()
{
JPDMainVersion=`curl -s -H "Authorization: Bearer $SOURCE_AUTH_TOKEN" "${JPD_A_URL}/artifactory/api/system/version"  | jq -r '.version'`
JPDTargetVersion=`curl -s -H "Authorization: Bearer $TARGET_AUTH_TOKEN" "${JPD_B_URL}/artifactory/api/system/version"  | jq -r '.version'`
echo "SourceJPDVersion,TargetJPDVersion" > JPDVersion.csv
echo "$JPDMainVersion,$JPDTargetVersion" >> JPDVersion.csv
JPDMainMajorVersion=`echo $JPDMainVersion  | cut -d "." -f1`
[ $JPDMainMajorVersion -eq 6 ] && jpd7=no
[ $JPDMainMajorVersion -eq 7 ] && jpd7=yes
}

LocalReposDetails()
{
echo "LocalRepoName,ExistsInTarget,SourceFilesCount,SourceUsedSpace,TargetFilesCount,TargetUsedSpace" > "$OUTPUT_LOCAL_CSV"
echo "LocalRepoName,FilesCount_Source,UsedSpace_Source" > "$ONLY_IN_SOURCE_LOCAL"
echo "LocalRepoName,FilesCount_Target,UsedSpace_Target" > "$ONLY_IN_TARGET_LOCAL"

echo "Processing Local Repos Details..."
jq -r '.repositoriesSummaryList[] | select(.repoType=="LOCAL") | .repoKey' "$STORAGE_A_FILE" | while read -r repo; do
    
    # Source Data
    filesA=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .filesCount' "$STORAGE_A_FILE")
    sizeA=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .usedSpace' "$STORAGE_A_FILE")
    
    # Target Check
    targetData=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo)' "$STORAGE_B_FILE")

    if [ -n "$targetData" ]; then
        exists="Yes"
        filesB=$(echo "$targetData" | jq -r '.filesCount')
        sizeB=$(echo "$targetData" | jq -r '.usedSpace')
    else
        exists="No"
        filesB="N/A"
        sizeB="N/A"
        # Log to "Only in Source" file
        echo "${repo},${filesA},${sizeA}" >> "$ONLY_IN_SOURCE_LOCAL"
    fi

    echo "${repo},${exists},${filesA},${sizeA},${filesB},${sizeB}" >> "$OUTPUT_LOCAL_CSV"
done

jq -r '.repositoriesSummaryList[] | select(.repoType=="LOCAL") | .repoKey' "$STORAGE_B_FILE" | while read -r repo; do
    
    # Check if this repo key is MISSING from Source JSON
    sourceCheck=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .repoKey' "$STORAGE_A_FILE")
    
    if [ -z "$sourceCheck" ]; then
        filesB=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .filesCount' "$STORAGE_B_FILE")
        sizeB=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .usedSpace' "$STORAGE_B_FILE")
        
        echo "${repo},${filesB},${sizeB}" >> "$ONLY_IN_TARGET_LOCAL"
    fi
done

echo "------------------------------------------------"
echo "Report Generation Complete for Local Repositories!"
echo "1. Full Local Repos Comparison: $OUTPUT_LOCAL_CSV"
echo "2. Local Repos Missing in Target: $ONLY_IN_SOURCE_LOCAL"
echo "3. Local Repos Missing in Source: $ONLY_IN_TARGET_LOCAL"
}

RemoteReposDetails()
{

echo "RemoteRepoName,ExistsInTarget" > "$OUTPUT_REMOTE_CSV"
echo "RemoteRepoName" > "$ONLY_IN_SOURCE_REMOTE"
echo "RemoteRepoName" > "$ONLY_IN_TARGET_REMOTE"

echo "Processing Remote Repos Details"

# Sourced from the repository CONFIGURATION list (.REMOTE[]), not storageinfo's CACHE
# entries - storageinfo only reports a remote repo once something has actually been
# cached through it, so a configured-but-never-used remote repo was silently absent from
# the old storageinfo-based count. The configuration list reflects every remote repo
# that's actually defined, which also makes this card's numbers consistent with the
# Remote Repo Configuration card below (same underlying source). Target always reads
# from REPOCONFIG_B_FILE's .REMOTE[] regardless of version, same as the config functions.
if [ "$jpd7" == "yes" ]; then
    sourceRemoteKeys=$(jq -r '.REMOTE[].key' "$REPOCONFIG_A_FILE")
else
    # 6.x source: REPOCONFIG_A_FILE holds the raw XML from /system/configuration - convert
    # the same way RemoteRepoConfigDetails2 does, so both read the identical derived file.
    REMOTE_REPOCONFIG_A_FILE="jpd_a_remote_repoconfig.json"
    awk '/<remoteRepositories>/,/<\/remoteRepositories>/' "$REPOCONFIG_A_FILE" | yq -p=xml -o=json '.' > "$REMOTE_REPOCONFIG_A_FILE"
    sourceRemoteKeys=$(jq -r '.remoteRepositories.remoteRepository[].key' "$REMOTE_REPOCONFIG_A_FILE")
fi

echo "$sourceRemoteKeys" | while read -r repo; do
    [ -z "$repo" ] && continue

    targetCheck=$(jq -r --arg repo "$repo" '.REMOTE[] | select(.key==$repo) | .key' "$REPOCONFIG_B_FILE")

    if [ -n "$targetCheck" ]; then
        exists="Yes"
    else
        exists="No"
        # Log to "Only in Source" file
        echo "${repo}" >> "$ONLY_IN_SOURCE_REMOTE"
    fi

    echo "${repo},${exists}" >> "$OUTPUT_REMOTE_CSV"
done

jq -r '.REMOTE[].key' "$REPOCONFIG_B_FILE" | while read -r repo; do

    # Check if this repo key is MISSING from Source
    if [ "$jpd7" == "yes" ]; then
        sourceCheck=$(jq -r --arg repo "$repo" '.REMOTE[] | select(.key==$repo) | .key' "$REPOCONFIG_A_FILE")
    else
        sourceCheck=$(jq -r --arg repo "$repo" '.remoteRepositories.remoteRepository[] | select(.key==$repo) | .key' "$REMOTE_REPOCONFIG_A_FILE")
    fi

    if [ -z "$sourceCheck" ]; then
        echo "${repo}" >> "$ONLY_IN_TARGET_REMOTE"
    fi
done

echo "------------------------------------------------"
echo "Report Generation Complete For Remote Repositories!"
echo "1. Full Remote Repos Comparison: $OUTPUT_REMOTE_CSV"
echo "2. Remote Repos Missing in Target: $ONLY_IN_SOURCE_REMOTE"
echo "3. Remote Repos Missing in Source: $ONLY_IN_TARGET_REMOTE"
}

VirtualReposDetails()
{
echo "VirtualRepoName,ExistsInTarget" > "$OUTPUT_VIRTUAL_CSV"
echo "VirtualRepoName" > "$ONLY_IN_SOURCE_VIRTUAL"
echo "VirtualRepoName" > "$ONLY_IN_TARGET_VIRTUAL"

echo "Processing Virtual Repos Details"
jq -r '.repositoriesSummaryList[] | select(.repoType=="VIRTUAL") | .repoKey' "$STORAGE_A_FILE" | while read -r repo; do


    # Target Check
    targetData=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo)' "$STORAGE_B_FILE")

    if [ -n "$targetData" ]; then
        exists="Yes"
    else
        exists="No"
        # Log to "Only in Source" file
        echo "${repo}" >> "$ONLY_IN_SOURCE_VIRTUAL"
    fi

    echo "${repo},${exists}" >> "$OUTPUT_VIRTUAL_CSV"
done 

jq -r '.repositoriesSummaryList[] | select(.repoType=="VIRTUAL") | .repoKey' "$STORAGE_B_FILE" | while read -r repo; do
    
    # Check if this repo key is MISSING from Source JSON
    sourceCheck=$(jq -r --arg repo "$repo" '.repositoriesSummaryList[] | select(.repoKey==$repo) | .repoKey' "$STORAGE_A_FILE")

    if [ -z "$sourceCheck" ]; then
        echo "${repo}" >> "$ONLY_IN_TARGET_VIRTUAL"
    fi
done
        
echo "------------------------------------------------"
echo "Report Generation Complete For Virtual Repositories!" 
echo "1. Full Virual Repository Comparison: $OUTPUT_VIRTUAL_CSV"
echo "2. Virtual Repos Missing in Target: $ONLY_IN_SOURCE_VIRTUAL"
echo "3. Virtual Repos Missing in Source: $ONLY_IN_TARGET_VIRTUAL"
}       


UsersDetails()
{
echo "Username,ExistsInTarget,SourceStatus,SourceRealm,TargetStatus,TargetRealm" > "$OUTPUT_USERS_CSV"
echo "Username,Status,Realm" > "$ONLY_IN_SOURCE_USERS"
echo "Username,Status,Realm" > "$ONLY_IN_TARGET_USERS"

echo "Processing Users Details..."
# Matching is case/whitespace-tolerant (trim + lowercase both sides before comparing), so a
# username that's otherwise identical but differs only by case or a stray trailing space
# (e.g. "JSmith " vs "jsmith") is correctly recognized as the same account rather than
# showing up as both "missing in target" and "only in target". The displayed name is still
# whatever the API returned, unmodified - only the match predicate is normalized.
jq -r '.users[] | "\(.username)|\(.status // "N/A")|\(.realm // "N/A")"' "$USERS_A_FILE" | while IFS="|" read -r user statusA realmA; do

    targetData=$(jq -r --arg u "$user" '.users[] | select((.username|gsub("^\\s+|\\s+$";"")|ascii_downcase) == ($u|gsub("^\\s+|\\s+$";"")|ascii_downcase)) | "\(.status // "N/A")|\(.realm // "N/A")"' "$USERS_B_FILE")

    if [ -n "$targetData" ]; then
        exists="Yes"
        statusB=$(echo "$targetData" | cut -d'|' -f1)
        realmB=$(echo "$targetData" | cut -d'|' -f2)
    else
        exists="No"
        statusB="N/A"
        realmB="N/A"
        echo "${user},${statusA},${realmA}" >> "$ONLY_IN_SOURCE_USERS"
    fi

    echo "${user},${exists},${statusA},${realmA},${statusB},${realmB}" >> "$OUTPUT_USERS_CSV"
done

jq -r '.users[].username' "$USERS_B_FILE" | while read -r user; do
    sourceCheck=$(jq -r --arg u "$user" '.users[] | select((.username|gsub("^\\s+|\\s+$";"")|ascii_downcase) == ($u|gsub("^\\s+|\\s+$";"")|ascii_downcase)) | .username' "$USERS_A_FILE")
    if [ -z "$sourceCheck" ]; then
        statusB=$(jq -r --arg u "$user" '.users[] | select(.username==$u) | .status // "N/A"' "$USERS_B_FILE")
        realmB=$(jq -r --arg u "$user" '.users[] | select(.username==$u) | .realm // "N/A"' "$USERS_B_FILE")
        echo "${user},${statusB},${realmB}" >> "$ONLY_IN_TARGET_USERS"
    fi
done

echo "------------------------------------------------"
echo "Report Generation Complete for Users!"
echo "1. Full Users Comparison: $OUTPUT_USERS_CSV"
echo "2. Users Missing in Target: $ONLY_IN_SOURCE_USERS"
echo "3. Users Missing in Source: $ONLY_IN_TARGET_USERS"
}

GroupsDetails()
{
echo "GroupName,ExistsInTarget" > "$OUTPUT_GROUPS_CSV"
echo "GroupName" > "$ONLY_IN_SOURCE_GROUPS"
echo "GroupName" > "$ONLY_IN_TARGET_GROUPS"

echo "Processing Groups Details..."
# Case/whitespace-tolerant match - see the comment in UsersDetails for why.
jq -r '.groups[].name' "$GROUPS_A_FILE" | while read -r grp; do

    targetCheck=$(jq -r --arg g "$grp" '.groups[] | select((.name|gsub("^\\s+|\\s+$";"")|ascii_downcase) == ($g|gsub("^\\s+|\\s+$";"")|ascii_downcase)) | .name' "$GROUPS_B_FILE")

    if [ -n "$targetCheck" ]; then
        exists="Yes"
    else
        exists="No"
        echo "${grp}" >> "$ONLY_IN_SOURCE_GROUPS"
    fi

    echo "${grp},${exists}" >> "$OUTPUT_GROUPS_CSV"
done

jq -r '.groups[].name' "$GROUPS_B_FILE" | while read -r grp; do
    sourceCheck=$(jq -r --arg g "$grp" '.groups[] | select((.name|gsub("^\\s+|\\s+$";"")|ascii_downcase) == ($g|gsub("^\\s+|\\s+$";"")|ascii_downcase)) | .name' "$GROUPS_A_FILE")
    if [ -z "$sourceCheck" ]; then
        echo "${grp}" >> "$ONLY_IN_TARGET_GROUPS"
    fi
done

echo "------------------------------------------------"
echo "Report Generation Complete for Groups!"
echo "1. Full Groups Comparison: $OUTPUT_GROUPS_CSV"
echo "2. Groups Missing in Target: $ONLY_IN_SOURCE_GROUPS"
echo "3. Groups Missing in Source: $ONLY_IN_TARGET_GROUPS"
}

PermissionsDetails()
{
# Existence/count comparison only - same shape as GroupsDetails. No per-permission detail
# calls are made, so this stays at a flat 2 API calls (the list fetch, one per side) no
# matter how many permission targets exist.
echo "PermissionName,ExistsInTarget" > "$OUTPUT_PERMISSIONS_CSV"
echo "PermissionName" > "$ONLY_IN_SOURCE_PERMISSIONS"
echo "PermissionName" > "$ONLY_IN_TARGET_PERMISSIONS"

echo "Processing Permissions Details..."
# Case/whitespace-tolerant match - see the comment in UsersDetails for why.
jq -r '.permissions[].name' "$PERMISSIONS_A_FILE" | while read -r perm; do

    targetCheck=$(jq -r --arg p "$perm" '.permissions[] | select((.name|gsub("^\\s+|\\s+$";"")|ascii_downcase) == ($p|gsub("^\\s+|\\s+$";"")|ascii_downcase)) | .name' "$PERMISSIONS_B_FILE")

    if [ -n "$targetCheck" ]; then
        exists="Yes"
    else
        exists="No"
        echo "${perm}" >> "$ONLY_IN_SOURCE_PERMISSIONS"
    fi

    echo "${perm},${exists}" >> "$OUTPUT_PERMISSIONS_CSV"
done

jq -r '.permissions[].name' "$PERMISSIONS_B_FILE" | while read -r perm; do
    sourceCheck=$(jq -r --arg p "$perm" '.permissions[] | select((.name|gsub("^\\s+|\\s+$";"")|ascii_downcase) == ($p|gsub("^\\s+|\\s+$";"")|ascii_downcase)) | .name' "$PERMISSIONS_A_FILE")
    if [ -z "$sourceCheck" ]; then
        echo "${perm}" >> "$ONLY_IN_TARGET_PERMISSIONS"
    fi
done

echo "------------------------------------------------"
echo "Report Generation Complete for Permissions!"
echo "1. Full Permissions Comparison: $OUTPUT_PERMISSIONS_CSV"
echo "2. Permissions Missing in Target: $ONLY_IN_SOURCE_PERMISSIONS"
echo "3. Permissions Missing in Source: $ONLY_IN_TARGET_PERMISSIONS"
}

TokensDetails()
{
# Just the count on each side - no active/expired/non-expiring breakdown.
echo "Processing Tokens Details..."
sourceTotal=$(jq -r '(.tokens // []) | length' "$TOKENS_A_FILE" 2>/dev/null)
targetTotal=$(jq -r '(.tokens // []) | length' "$TOKENS_B_FILE" 2>/dev/null)
sourceTotal=${sourceTotal:-0}; targetTotal=${targetTotal:-0}
[ "$sourceTotal" == "null" ] && sourceTotal=0
[ "$targetTotal" == "null" ] && targetTotal=0

echo "Metric,Source,Target" > "$OUTPUT_TOKENS_CSV"
echo "TotalTokens,${sourceTotal},${targetTotal}" >> "$OUTPUT_TOKENS_CSV"

echo "------------------------------------------------"
echo "Report Generation Complete for Tokens!"
echo "1. Token Count Summary: $OUTPUT_TOKENS_CSV"
}

RemoteRepoConfigDetails2() {
    

echo "SourceRepoName,SourceURL,SourcePasswordExists,TargetRepoName,TargetURL,TargetPasswordExists,ExistsInTarget,DifferenceInConfig" > "$OUTPUT_REMOTE_CONFIG_CSV"
echo "RemoteRepoName" > "$ONLY_IN_TARGET_REMOTE_CONFIG"
echo "Processing Remote Repo config comparision between JPDs"
REMOTE_REPOCONFIG_A_FILE="jpd_a_remote_repoconfig.json"

awk '/<remoteRepositories>/,/<\/remoteRepositories>/' $REPOCONFIG_A_FILE | yq -p=xml -o=json '.' > "$REMOTE_REPOCONFIG_A_FILE"
jq -r '.remoteRepositories.remoteRepository[] | "\(.key)|\(.url // "N/A")|\(.password // "")"' "$REMOTE_REPOCONFIG_A_FILE" | while IFS="|" read -r repoA urlA passA; do

    # Check Password for Source
    if [ -z "$passA" ] || [ "$passA" == "null" ]; then
        SrcPasswordExists="No"
    else
        SrcPasswordExists="Yes"
    fi

    # 2. Check if this repo exists anywhere in File B's REMOTE section and fetch its password
    targetData=$(jq -r --arg repo "$repoA" '.REMOTE[] | select(.key == $repo) | "\(.url // "N/A")|\(.password // "")"' "$REPOCONFIG_B_FILE")

    if [ -n "$targetData" ]; then
        exists="Yes"
        urlB=$(echo "$targetData" | cut -d'|' -f1)
        passB=$(echo "$targetData" | cut -d'|' -f2)

        # Check Password for Target
        if [ -z "$passB" ] || [ "$passB" == "null" ]; then
            TgtPasswordExists="No"
        else
            TgtPasswordExists="Yes"
        fi
    else
        exists="No"
        urlB="N/A"
        TgtPasswordExists="N/A"
    fi

    # DifferenceInConfig flags a URL or password-presence mismatch on a repo that exists on
    # both sides - N/A when it doesn't exist in target at all (nothing to diff against).
    if [ "$exists" == "Yes" ]; then
        if [ "$urlA" != "$urlB" ] || [ "$SrcPasswordExists" != "$TgtPasswordExists" ]; then
            isDiff="Yes"
        else
            isDiff="No"
        fi
    else
        isDiff="N/A"
    fi

    echo "$repoA,$urlA,$SrcPasswordExists,$repoA,$urlB,$TgtPasswordExists,$exists,$isDiff" >> "$OUTPUT_REMOTE_CONFIG_CSV"
done

# Reverse direction: remote repo configs that exist in target but not in source
jq -r '.REMOTE[].key' "$REPOCONFIG_B_FILE" | while read -r repoB; do
    sourceCheck=$(jq -r --arg repo "$repoB" '.remoteRepositories.remoteRepository[] | select(.key == $repo) | .key' "$REMOTE_REPOCONFIG_A_FILE")
    if [ -z "$sourceCheck" ]; then
        echo "${repoB}" >> "$ONLY_IN_TARGET_REMOTE_CONFIG"
    fi
done

echo "Remote Repos Config comparison complete! Saved to: $OUTPUT_REMOTE_CONFIG_CSV"
}

RemoteRepoConfigDetails()
{       
echo "SourceRepoName,SourceURL,SourcePasswordExists,TargetRepoName,TargetURL,TargetPasswordExists,ExistsInTarget,DifferenceInConfig" > "$OUTPUT_REMOTE_CONFIG_CSV"
echo "RemoteRepoName" > "$ONLY_IN_TARGET_REMOTE_CONFIG"
echo "Processing Remote Repo config comparision between JPDs"
jq -r '.REMOTE[] | "\(.key)|\(.url // "N/A")|\(.password // "")"' "$REPOCONFIG_A_FILE" | while IFS="|" read -r repoA urlA passA; do

    # Check Password for Source
    if [ -z "$passA" ] || [ "$passA" == "null" ]; then
        SrcPasswordExists="No"
    else
        SrcPasswordExists="Yes"
    fi

    # 2. Check if this repo exists anywhere in File B's REMOTE section and fetch its password
    targetData=$(jq -r --arg repo "$repoA" '.REMOTE[] | select(.key == $repo) | "\(.url // "N/A")|\(.password // "")"' "$REPOCONFIG_B_FILE")

    if [ -n "$targetData" ]; then
        exists="Yes"
        urlB=$(echo "$targetData" | cut -d'|' -f1)
        passB=$(echo "$targetData" | cut -d'|' -f2)

        # Check Password for Target
        if [ -z "$passB" ] || [ "$passB" == "null" ]; then
            TgtPasswordExists="No"
        else
            TgtPasswordExists="Yes"
        fi
    else
        exists="No"
        urlB="N/A"
        TgtPasswordExists="N/A"
    fi

    # DifferenceInConfig flags a URL or password-presence mismatch on a repo that exists on
    # both sides - N/A when it doesn't exist in target at all (nothing to diff against).
    if [ "$exists" == "Yes" ]; then
        if [ "$urlA" != "$urlB" ] || [ "$SrcPasswordExists" != "$TgtPasswordExists" ]; then
            isDiff="Yes"
        else
            isDiff="No"
        fi
    else
        isDiff="N/A"
    fi

    echo "$repoA,$urlA,$SrcPasswordExists,$repoA,$urlB,$TgtPasswordExists,$exists,$isDiff" >> "$OUTPUT_REMOTE_CONFIG_CSV"
done

# Reverse direction: remote repo configs that exist in target but not in source
jq -r '.REMOTE[].key' "$REPOCONFIG_B_FILE" | while read -r repoB; do
    sourceCheck=$(jq -r --arg repo "$repoB" '.REMOTE[] | select(.key == $repo) | .key' "$REPOCONFIG_A_FILE")
    if [ -z "$sourceCheck" ]; then
        echo "${repoB}" >> "$ONLY_IN_TARGET_REMOTE_CONFIG"
    fi
done

echo "Remote Repos Config comparison complete! Saved to: $OUTPUT_REMOTE_CONFIG_CSV"
}


VirtualRepoConfigDetails()
{

# 1. Initialize CSV Header
# Column 8 (isDiff) will flag if the underlying repository lists don't match
HEADER="SourceRepoName,SourceRepositories,SourceDefaultDeploy,TargetRepoName,TargetRepositories,TargetDefaultDeploy,ExistsInTarget,DifferenceInRepos"
echo "$HEADER" > "$OUTPUT_VIRTUAL_CONFIG_CSV"
echo "VirtualRepoName" > "$ONLY_IN_TARGET_VIRTUAL_CONFIG"

echo "Processing Virtual Repos config comparision between JPDs"

# 2. Extract specifically from the .VIRTUAL array
# We join the 'repositories' array using join(";") for easier CSV handling
jq -r '.VIRTUAL[] | "\(.key)|\(.repositories | sort | join(";"))|\(.defaultDeploymentRepo // "N/A")"' "$REPOCONFIG_A_FILE" | while IFS="|" read -r repoA childrenA deployA; do

    # 3. Search for the same Virtual Repo in File B
    targetMatch=$(jq -r --arg repo "$repoA" '.VIRTUAL[] | select(.key == $repo) | "\(.key)|\(.repositories | sort |  join(";"))|\(.defaultDeploymentRepo // "N/A")"' "$REPOCONFIG_B_FILE")

    if [ -n "$targetMatch" ]; then
        exists="Yes"
        repoB=$(echo "$targetMatch" | cut -d'|' -f1)
        childrenB=$(echo "$targetMatch" | cut -d'|' -f2)
        deployB=$(echo "$targetMatch" | cut -d'|' -f3)

        # 4. Check for differences in the underlying repository list
        if [ "$childrenA" == "$childrenB" ]; then
            isDiff="No"
        else
            isDiff="Yes"
        fi
    else
        exists="No"
        repoB="N/A"
        childrenB="N/A"
        deployB="N/A"
        isDiff="N/A"
    fi

    # Append to CSV
    echo "${repoA},\"${childrenA}\",${deployA},${repoB},\"${childrenB}\",${deployB},${exists},${isDiff}" >> "$OUTPUT_VIRTUAL_CONFIG_CSV"
done

# Reverse direction: virtual repo configs that exist in target but not in source
jq -r '.VIRTUAL[].key' "$REPOCONFIG_B_FILE" | while read -r repoB; do
    sourceCheck=$(jq -r --arg repo "$repoB" '.VIRTUAL[] | select(.key == $repo) | .key' "$REPOCONFIG_A_FILE")
    if [ -z "$sourceCheck" ]; then
        echo "${repoB}" >> "$ONLY_IN_TARGET_VIRTUAL_CONFIG"
    fi
done

echo "------------------------------------------------"
echo "Virtual Repos Config comparison complete! Saved to: $OUTPUT_VIRTUAL_CONFIG_CSV"
}

VirtualRepoConfigDetails2() {

# 1. Initialize CSV Header
# Column 8 (isDiff) will flag if the underlying repository lists don't match
HEADER="SourceRepoName,SourceRepositories,SourceDefaultDeploy,TargetRepoName,TargetRepositories,TargetDefaultDeploy,ExistsInTarget,DifferenceInRepos"
echo "$HEADER" > "$OUTPUT_VIRTUAL_CONFIG_CSV"
echo "VirtualRepoName" > "$ONLY_IN_TARGET_VIRTUAL_CONFIG"

echo "Processing Virtual Repos config comparision between JPDs"

# 2. Extract specifically from the .VIRTUAL array
# We join the 'repositories' array using join(";") for easier CSV handling
VIRTUAL_REPOCONFIG_A_FILE="jpd_a_virtual_repoconfig.json"

awk '/<virtualRepositories>/,/<\/virtualRepositories>/' $REPOCONFIG_A_FILE | yq -p=xml -o=json '.' > "$VIRTUAL_REPOCONFIG_A_FILE"
jq -r '.virtualRepositories.virtualRepository[] |"\(.key)|\(if (.repositories.repositoryRef | type) == "array" then (.repositories.repositoryRef | sort | join(";"))  else .repositories.repositoryRef  end)|\(.defaultDeploymentRepo // "N/A")"' "$VIRTUAL_REPOCONFIG_A_FILE" | while IFS="|" read -r repoA childrenA deployA; do

    # 3. Search for the same Virtual Repo in File B
    targetMatch=$(jq -r --arg repo "$repoA" '.VIRTUAL[] | select(.key == $repo) | "\(.key)|\(.repositories | sort | join(";"))|\(.defaultDeploymentRepo // "N/A")"' "$REPOCONFIG_B_FILE")

    if [ -n "$targetMatch" ]; then
        exists="Yes"
        repoB=$(echo "$targetMatch" | cut -d'|' -f1)
        childrenB=$(echo "$targetMatch" | cut -d'|' -f2)
        deployB=$(echo "$targetMatch" | cut -d'|' -f3)

        # 4. Check for differences in the underlying repository list
        if [ "$childrenA" == "$childrenB" ]; then
            isDiff="No"
        else
            isDiff="Yes"
        fi
    else
        exists="No"
        repoB="N/A"
        childrenB="N/A"
        deployB="N/A"
        isDiff="N/A"
    fi

    # Append to CSV
    echo "${repoA},\"${childrenA}\",${deployA},${repoB},\"${childrenB}\",${deployB},${exists},${isDiff}" >> "$OUTPUT_VIRTUAL_CONFIG_CSV"
done

# Reverse direction: virtual repo configs that exist in target but not in source
jq -r '.VIRTUAL[].key' "$REPOCONFIG_B_FILE" | while read -r repoB; do
    sourceCheck=$(jq -r --arg repo "$repoB" '.virtualRepositories.virtualRepository[] | select(.key == $repo) | .key' "$VIRTUAL_REPOCONFIG_A_FILE")
    if [ -z "$sourceCheck" ]; then
        echo "${repoB}" >> "$ONLY_IN_TARGET_VIRTUAL_CONFIG"
    fi
done

echo "------------------------------------------------"
echo "Virtual Repos Config comparison complete! Saved to: $OUTPUT_VIRTUAL_CONFIG_CSV"
}

FormatRepoComparision()
{
FinalComparisionCSV="repo_comparision_consolidated.csv"

echo "" > $FinalComparisionCSV
echo "---------------------Local repository comparision Details------------------------" >> $FinalComparisionCSV
cat $OUTPUT_LOCAL_CSV >> $FinalComparisionCSV

echo "" >> $FinalComparisionCSV
echo "--------------------Remote repository comparision Details------------------------" >> $FinalComparisionCSV
cat $OUTPUT_REMOTE_CSV >> $FinalComparisionCSV

echo "" >> $FinalComparisionCSV
echo "--------------------Virtual repository comparision Details-----------------------" >> $FinalComparisionCSV
cat $OUTPUT_VIRTUAL_CSV >> $FinalComparisionCSV
}

FormatSecurityComparision()
{
FinalSecurityCSV="security_comparision_consolidated.csv"

echo "" > $FinalSecurityCSV
echo "---------------------Users comparision Details------------------------" >> $FinalSecurityCSV
cat $OUTPUT_USERS_CSV >> $FinalSecurityCSV

echo "" >> $FinalSecurityCSV
echo "---------------------Groups comparision Details------------------------" >> $FinalSecurityCSV
cat $OUTPUT_GROUPS_CSV >> $FinalSecurityCSV

echo "" >> $FinalSecurityCSV
echo "---------------------Permissions comparision Details------------------------" >> $FinalSecurityCSV
cat $OUTPUT_PERMISSIONS_CSV >> $FinalSecurityCSV

echo "" >> $FinalSecurityCSV
echo "---------------------Tokens count summary------------------------" >> $FinalSecurityCSV
cat $OUTPUT_TOKENS_CSV >> $FinalSecurityCSV
}

FormatRepoConfigComparision()
{
FinalComparisionConfigCSV="repo_comparision_config_consolidated.csv"

echo "" > $FinalComparisionConfigCSV
echo "--------------------Remote repository config comparision Details------------------------" >> $FinalComparisionConfigCSV
cat $OUTPUT_REMOTE_CONFIG_CSV >> $FinalComparisionConfigCSV

echo "" >> $FinalComparisionConfigCSV
echo "--------------------Virtual repository config comparision Details-----------------------" >> $FinalComparisionConfigCSV
cat $OUTPUT_VIRTUAL_CONFIG_CSV >> $FinalComparisionConfigCSV
}

echo "Getting ready to Prepare comparision between the JPDs"
ValidateInputs
GetSourceVersion
###Fetching storage info from both JPDs
curl -s -H "Authorization: Bearer $SOURCE_AUTH_TOKEN" "${JPD_A_URL}/artifactory/api/storageinfo" -o "$STORAGE_A_FILE"
curl -s -H "Authorization: Bearer $TARGET_AUTH_TOKEN" "${JPD_B_URL}/artifactory/api/storageinfo" -o "$STORAGE_B_FILE"

##--Fetch repo config json

if [ $jpd7 == "yes" ];then
	curl -s -H "Authorization: Bearer $SOURCE_AUTH_TOKEN" "${JPD_A_URL}/artifactory/api/repositories/configurations" -o "$REPOCONFIG_A_FILE"
	curl -s -H "Authorization: Bearer $TARGET_AUTH_TOKEN" "${JPD_B_URL}/artifactory/api/repositories/configurations" -o "$REPOCONFIG_B_FILE"
else
	curl -s -H "Authorization: Bearer $SOURCE_AUTH_TOKEN" "${JPD_A_URL}/artifactory/api/system/configuration" -o "$REPOCONFIG_A_FILE"
	curl -s -H "Authorization: Bearer $TARGET_AUTH_TOKEN" "${JPD_B_URL}/artifactory/api/repositories/configurations" -o "$REPOCONFIG_B_FILE"
fi

##--Fetch users/groups/permissions/tokens via the Access API (JPD 7.x only - these
##--endpoints don't exist on legacy 6.x installs). If the token isn't admin-scoped for the
##--Access API, these calls will come back 401/403 with an empty body - the Normalize*File
##--functions degrade that to an empty {"users":[]}/{"groups":[]}/etc rather than erroring,
##--so the rest of the script still completes, just with empty users/groups/permissions
##--sections. (Tokens has no separate normalize step, but TokensDetails itself guards
##--against a missing/invalid response and reports 0 rather than erroring.)
if [ "$jpd7" == "yes" ];then
	FetchPaginated "${JPD_A_URL}/access/api/v2/users?limit=120000" "$SOURCE_AUTH_TOKEN" "$USERS_A_FILE" "users"
	FetchPaginated "${JPD_B_URL}/access/api/v2/users?limit=120000" "$TARGET_AUTH_TOKEN" "$USERS_B_FILE" "users"
	NormalizeUsersFile "$USERS_A_FILE"
	NormalizeUsersFile "$USERS_B_FILE"

	# limit is set generously high so the common case is a single page; the pagination loop
	# in FetchPaginated still kicks in as a fallback if a given JPD clamps it lower anyway.
	FetchPaginated "${JPD_A_URL}/access/api/v2/groups?limit=100000" "$SOURCE_AUTH_TOKEN" "$GROUPS_A_FILE" "groups"
	FetchPaginated "${JPD_B_URL}/access/api/v2/groups?limit=100000" "$TARGET_AUTH_TOKEN" "$GROUPS_B_FILE" "groups"
	NormalizeGroupsFile "$GROUPS_A_FILE"
	NormalizeGroupsFile "$GROUPS_B_FILE"

	# Permissions API docs state limit must be between 1 and 99,999 (non-inclusive), so 99998
	# is the highest valid value - anything beyond that gets clamped or rejected depending on version.
	FetchPaginated "${JPD_A_URL}/access/api/v2/permissions?limit=99998" "$SOURCE_AUTH_TOKEN" "$PERMISSIONS_A_FILE" "permissions"
	FetchPaginated "${JPD_B_URL}/access/api/v2/permissions?limit=99998" "$TARGET_AUTH_TOKEN" "$PERMISSIONS_B_FILE" "permissions"
	NormalizePermissionsFile "$PERMISSIONS_A_FILE"
	NormalizePermissionsFile "$PERMISSIONS_B_FILE"

	curl -s -H "Authorization: Bearer $SOURCE_AUTH_TOKEN" "${JPD_A_URL}/access/api/v1/tokens" -o "$TOKENS_A_FILE"
	curl -s -H "Authorization: Bearer $TARGET_AUTH_TOKEN" "${JPD_B_URL}/access/api/v1/tokens" -o "$TOKENS_B_FILE"

	# Quick sanity check: warn loudly (not just a silent null) if normalization couldn't find
	# a usable name field anywhere, so it's obvious at the console rather than discovered later
	# buried in a CSV.
	unknownUsers=$(jq -r '[.users[]? | select(.username=="UNKNOWN_FIELD")] | length' "$USERS_A_FILE" 2>/dev/null)
	unknownGroups=$(jq -r '[.groups[]? | select(.name=="UNKNOWN_FIELD")] | length' "$GROUPS_A_FILE" 2>/dev/null)
	unknownPerms=$(jq -r '[.permissions[]? | select(.name=="UNKNOWN_FIELD")] | length' "$PERMISSIONS_A_FILE" 2>/dev/null)
	unknownUsers=${unknownUsers:-0}; unknownGroups=${unknownGroups:-0}; unknownPerms=${unknownPerms:-0}
	[ "$unknownUsers" == "null" ] && unknownUsers=0
	[ "$unknownGroups" == "null" ] && unknownGroups=0
	[ "$unknownPerms" == "null" ] && unknownPerms=0

	if [ "$unknownUsers" -gt 0 ]; then
		echo "WARNING: $unknownUsers source user(s) came back with an unrecognized name field."
		echo "         Inspect the raw response with: curl -s -H \"Authorization: Bearer \$SOURCE_AUTH_TOKEN\" \"${JPD_A_URL}/access/api/v2/users?limit=1\" | jq ."
	fi
	if [ "$unknownGroups" -gt 0 ]; then
		echo "WARNING: $unknownGroups source group(s) came back with an unrecognized name field - this is likely why groups were showing as null/blank."
		echo "         Inspect the raw response with: curl -s -H \"Authorization: Bearer \$SOURCE_AUTH_TOKEN\" \"${JPD_A_URL}/access/api/v2/groups?limit=1\" | jq ."
	fi
	if [ "$unknownPerms" -gt 0 ]; then
		echo "WARNING: $unknownPerms source permission(s) came back with an unrecognized name field."
		echo "         Inspect the raw response with: curl -s -H \"Authorization: Bearer \$SOURCE_AUTH_TOKEN\" \"${JPD_A_URL}/access/api/v2/permissions?limit=1\" | jq ."
	fi
fi

LocalReposDetails
echo ""
RemoteReposDetails
echo ""
VirtualReposDetails
echo ""
if [ $jpd7 == "yes" ];then
	RemoteRepoConfigDetails
	echo ""
	VirtualRepoConfigDetails
	echo ""
else
	RemoteRepoConfigDetails2	
	echo ""
	VirtualRepoConfigDetails2
	echo ""
fi
FormatRepoComparision
echo ""
#FormatRepoConfigComparision
echo ""

if [ "$jpd7" == "yes" ];then
	UsersDetails
	echo ""
	GroupsDetails
	echo ""
	PermissionsDetails
	echo ""
	TokensDetails
	echo ""
	FormatSecurityComparision
	echo ""
else
	echo "Skipping Users/Groups/Permissions/Tokens comparison: Access API (v2 users/groups/permissions, v1 tokens) requires JPD 7.x. Source is detected as 6.x."
	echo ""
fi
# --- 3. Web Server Automation ---
if [[ "$WEB_OUTPUT" == "yes" ]]; then
    echo "------------------------------------------------"
    echo "Starting Web Server on http://localhost:8000"
    echo "Dashboard: http://localhost:8000/CompareJPDsRepoConfig.html"
    echo "Press Ctrl+C to stop the server when finished."
    
    # Open the browser automatically based on OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "http://localhost:8000/CompareJPDsRepoConfig.html" &>/dev/null &
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "http://localhost:8000/CompareJPDsRepoConfig.html" &>/dev/null &
    fi

    # Run the server (this will block the script until you hit Ctrl+C)
    python3 -m http.server 8000
else
    echo "------------------------------------------------"
    echo "Web output disabled. Reports generated in CSV format."
fi
