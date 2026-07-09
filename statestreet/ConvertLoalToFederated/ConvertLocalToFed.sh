#! /bin/bash

# JFrog hereby grants you a non-exclusive, non-transferable, non-distributable right to use this  code   solely in connection with your use of a JFrog product or service. This  code is provided 'as-is' and without any warranties or conditions, either express or implied including, without limitation, any warranties or conditions of title, non-infringement, merchantability or fitness for a particular cause. Nothing herein shall convey to you any right or title in the code, other than for the limited use right set forth herein. For the purposes hereof "you" shall mean you as an individual as well as the organization on behalf of which you are using the software and the JFrog product or service. 

### Exit the script on any failures
set -eo pipefail
set -e
set -u

### Get Arguments
SOURCE_JPD_URL="${1:?please enter JPD URL. ex - https://jpd1.jfrog.io}"
USER_NAME="${2:?please provide the admin username in JPD . ex - admin}"
JPD_AUTH_TOKEN="${3:?please provide the identity token}"
AccessMembers="${4:?please provide the member details. ex - abc.jfrog.io,xyz.jfrog.io}"

### define variables
reposfile="localrepos.txt"

##############Functions section#################

GenerateAccessJson()
{
reponame=$1
for i in `echo $AccessMembers | tr "," " "`
do
urlval="https://$i/artifactory/$reponame"
res=$(jq -n \
    --arg url "$urlval" \
    '{ "url": $url, "enabled": true } ')
echo $res >> "cl2f.generated.$reponame.json"
done
}

Finish()
{
###remove temporary files created by this script
rm cl2f.* > /dev/null
}

###########Functions section Ends################

### Run the curl API
rm -rf *.json
#curl -XGET -H 'Content-Type: application/json' -u "${USER_NAME}":"${JPD_AUTH_TOKEN}" "${SOURCE_JPD_URL}/artifactory/api/repositories?type=local" -s | jq -rc '.[] | .key' > $reposfile

while IFS= read -r repo; do
    echo "\nPerforming conversion of Local to Federated repo for $repo"
    curl -XPOST -H 'Content-Type: application/json' -u "${USER_NAME}":"${JPD_AUTH_TOKEN}" "$SOURCE_JPD_URL/artifactory/api/federation/migrate/$repo"
    echo ""

    if [ ! -z "$AccessMembers" ];then
        sleep 1
        ###Download json file to update
        downfilename="cl2f.down.$repo.json"
        curl -s -o $downfilename -XGET -H 'Content-Type: application/json' -u "${USER_NAME}":"${JPD_AUTH_TOKEN}" "$SOURCE_JPD_URL/artifactory/api/repositories/$repo"

        ###Update the downloaded JSON by adding members
        GenerateAccessJson $repo
        jq '.members += [inputs]' $downfilename cl2f.generated.$reponame.json > cl2f.updated.$repo.json

        ###Update repository configuration
        curl -XPOST -H 'Content-Type: application/json' -T "cl2f.updated.$repo.json" -u "${USER_NAME}":"${JPD_AUTH_TOKEN}" "$SOURCE_JPD_URL/artifactory/api/repositories/$repo"
   fi
done < $reposfile

#Finish

### sample cmd to run - ./convertLocalToFed.sh https://ramkannan.jfrog.io admin ****
