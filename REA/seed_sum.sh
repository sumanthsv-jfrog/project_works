#!/usr/bin/env bash
#
# Generates test artifacts from scratch and uploads them to the
# sum- raw, maven, and npm repositories in Nexus.
#
# Usage:
#   export NEXUS_PASSWORD='your-admin-password'
#   ./seed-sum-repos.sh
#
set -euo pipefail

NEXUS="${NEXUS:-http://172.18.98.95:8081}"
HOST="${NEXUS#http://}"; HOST="${HOST%%/*}"   # strips scheme+path -> 172.18.98.95:8081
USER="${NEXUS_USER:-admin}"
PASS="${NEXUS_PASSWORD:-1Q2w3e4r}"
AUTH="$USER:$PASS"

WORK="$(mktemp -d)"
echo "Working in $WORK"
cd "$WORK"

# ---------------------------------------------------------------------------
echo
echo "=== 1. RAW (generic) ==="
echo "migration test payload generated $(date)" > sample.txt
dd if=/dev/urandom of=blob.bin bs=1M count=2 status=none

curl -fsS -u "$AUTH" --upload-file sample.txt \
  "$NEXUS/repository/sum-raw-hosted/test/v1/sample.txt" && echo "  uploaded sample.txt"
curl -fsS -u "$AUTH" --upload-file blob.bin \
  "$NEXUS/repository/sum-raw-hosted/test/v1/blob.bin"   && echo "  uploaded blob.bin"

# ---------------------------------------------------------------------------
echo
echo "=== 2. MAVEN (release + snapshot) ==="
if command -v mvn >/dev/null 2>&1; then
  mvn -q archetype:generate \
    -DgroupId=com.example.migtest -DartifactId=demo-lib \
    -DarchetypeArtifactId=maven-archetype-quickstart \
    -DarchetypeVersion=1.4 -DinteractiveMode=false
  cd demo-lib

  # add distributionManagement
  python3 - <<'PY'
import re
p = "pom.xml"
s = open(p).read()
dm = """  <distributionManagement>
    <repository><id>nexus</id><url>http://172.18.98.95:8081/repository/sum-maven-releases/</url></repository>
    <snapshotRepository><id>nexus</id><url>http://172.18.98.95:8081/repository/sum-maven-snapshots/</url></snapshotRepository>
  </distributionManagement>
"""
s = s.replace("</project>", dm + "</project>")
open(p, "w").write(s)
PY

  # settings.xml with creds (server id must match the <id> above)
  cat > settings.xml <<EOF
<settings><servers>
  <server><id>nexus</id><username>$USER</username><password>$PASS</password></server>
</servers></settings>
EOF

  echo "  deploying 1.0-SNAPSHOT ..."
  mvn -q -s settings.xml clean deploy

  echo "  deploying 1.0.0 release ..."
  mvn -q versions:set -DnewVersion=1.0.0
  mvn -q -s settings.xml clean deploy
  echo "  maven deploy complete"
  cd "$WORK"
else
  echo "  mvn not found - skipping. Install with: sudo apt install -y maven"
fi

# ---------------------------------------------------------------------------
echo
echo "=== 3. NPM ==="
if command -v npm >/dev/null 2>&1; then
  mkdir sum-npm-test && cd sum-npm-test
  npm init -y >/dev/null
  npm pkg set name="sum-demo-pkg" version="1.0.0" >/dev/null

  TOKEN=$(printf '%s' "$AUTH" | base64)
  cat > .npmrc <<EOF
registry=$NEXUS/repository/sum-npm-hosted/
//$HOST/repository/sum-npm-hosted/:_auth=$TOKEN
email=admin@example.com
always-auth=true
EOF

  npm publish && echo "  published sum-demo-pkg@1.0.0"

  echo "  seeding npm proxy cache (lodash) ..."
  npm install lodash --registry "$NEXUS/repository/sum-npm-proxy/" \
    --prefix "$WORK/proxy-test" --no-save >/dev/null 2>&1 && echo "  proxy cached lodash"
  cd "$WORK"
else
  echo "  npm not found - skipping. Install with: sudo apt install -y nodejs npm"
fi

# ---------------------------------------------------------------------------
echo
echo "=== Verify ==="
for r in sum-raw-hosted sum-maven-releases sum-maven-snapshots sum-npm-hosted sum-npm-proxy; do
  echo "-- $r --"
  curl -s -u "$AUTH" "$NEXUS/service/rest/v1/components?repository=$r" \
    | grep -o '"name": *"[^"]*"' | cut -d'"' -f4 | sort -u | sed 's/^/   /'
done

echo
echo "Done. Temp files in $WORK (safe to delete)."
