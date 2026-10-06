export  SOURCE_URL="psblr.jfrog.io"
export  SOURCE_TOKEN=""
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/artifactory/api/system/version" > jpd_a_version.json
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/artifactory/api/storageinfo" > jpd_a_storageinfo.json
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/artifactory/api/repositories/configurations" > jpd_a_repoconfig.json
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/access/api/v2/users?limit=120000" > jpd_a_users.json
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/access/api/v2/groups?limit=100000" > jpd_a_groups.json
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/access/api/v2/permissions?limit=99998" > jpd_a_permissions.json
curl -s -H "Authorization: Bearer $SOURCE_TOKEN" "https://$SOURCE_URL/access/api/v1/tokens" > jpd_a_tokens.json


export  TARGET_URL="psblrdr.jfrog.io"
export  TARGET_TOKEN=""
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/artifactory/api/system/version" > jpd_b_version.json
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/artifactory/api/storageinfo" > jpd_b_storageinfo.json
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/artifactory/api/repositories/configurations" > jpd_b_repoconfig.json
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/access/api/v2/users?limit=120000" > jpd_b_users.json
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/access/api/v2/groups?limit=100000" > jpd_b_groups.json
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/access/api/v2/permissions?limit=99998" > jpd_b_permissions.json
curl -s -H "Authorization: Bearer $TARGET_TOKEN" "https://$TARGET_URL/access/api/v1/tokens" > jpd_b_tokens.json
