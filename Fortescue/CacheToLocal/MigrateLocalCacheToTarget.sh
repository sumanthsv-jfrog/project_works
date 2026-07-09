#!/bin/bash
sourceid=$1
targetid=$2
localrepofile="cachelocals.txt"

repo_dir="repos"
mkdir -p $repo_dir


GetLocalRepos()
{
echo "Fetching repos list on Source and Target JPDs..."
jf rt curl -s -XGET "/api/repositories?type=local" --server-id=$targetid | jq -r '.[] | .key' | sort > available_target.txt
jf rt curl -s -XGET "/api/repositories?type=local" --server-id=$sourceid | jq -r '.[] | .key' | sort > available_source.txt
}

Action()
{
for i in `cat $localrepofile`
do
	echo "Processing repository $i..."
	cat available_target.txt | grep -w "$i" > /dev/null 2>&1
	if [ $? -eq 0 ];then
		echo "Repository $i already exist in target server $targetid"
		continue
	else
		cat available_source.txt | grep -w "$i" > /dev/null 2>&1
		if [ $? -eq 0 ];then
			jf rt curl -s -XGET "/api/repositories/$i" --server-id=$sourceid > $repo_dir/$i.json
			sleep 1
			jf rt curl -XPUT "/api/repositories/$i" --server-id=$targetid -T $repo_dir/$i.json -s -H 'Content-Type: application/json'
		else
			echo "Provided repository $i not exist on source server $sourceid"
		fi
	fi
done
}

GetLocalRepos
Action
