#!/usr/bin/env bash
#
# fetch-jfrog-logs.sh
# Maintains a local MIRROR of the latest day of JFrog logs, one folder per
# service. Each run replaces (overrides) the previous contents, so the tree
# always holds just the most recent batch for your observability uploader:
#
#   logs_collection/
#     artifactory/    <- latest day's logs (flattened files)
#     xray/
#     distribution/
#
# Usage:
#   export JF_URL="https://psblr.jfrog.io"
#   export JFROG_TOKEN="<access-token>"      # needs read on jfrog-logs
#   ./fetch-jfrog-logs.sh
#
#   DATE=2026-06-28 ./fetch-jfrog-logs.sh            # pin a specific day
#   SERVICES="artifactory xray" ./fetch-jfrog-logs.sh
#   BASE_DIR=/var/log/jfrog ./fetch-jfrog-logs.sh
#
set -euo pipefail

# ----------------------------- config ---------------------------------------
JF_URL="${JF_URL:-https://psblr.jfrog.io}"
JFROG_TOKEN="${JFROG_TOKEN:-}"
REPO="${REPO:-jfrog-logs}"
BASE_DIR="${BASE_DIR:-logs_collection}"
SERVICES="${SERVICES:-artifactory}"        # empty = auto-discover (artifactory/xray/distribution/...)
DATE="${DATE:-2026-07-01}"                # empty = latest available day per service (UTC)
VERIFY_SHA="${VERIFY_SHA:-true}"
RETRIES="${RETRIES:-3}"
SLEEP="${SLEEP:-0}"             # seconds between downloads; raise to e.g. 0.2 if you hit HTTP 429
# ----------------------------------------------------------------------------

log(){ printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."
command -v jq   >/dev/null 2>&1 || die "jq is required (apt/brew install jq)."
[ -n "$JFROG_TOKEN" ] || die "JFROG_TOKEN is not set."
AUTH=(-H "Authorization: Bearer ${JFROG_TOKEN}")

# clean up any leftover staging dirs on exit
STAGES=()
cleanup(){ for s in "${STAGES[@]:-}"; do [ -n "${s:-}" ] && rm -rf "$s"; done; }
trap cleanup EXIT

sha256_of(){
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum  >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else echo ""; fi
}

# storage list: $1=path under repo (may be empty)  $2=deep(0/1)  $3=listFolders(0/1)
list_path(){
  curl -fsS "${AUTH[@]}" \
    "${JF_URL}/artifactory/api/storage/${REPO}${1}?list&deep=${2}&listFolders=${3}&mdTimestamps=0"
}

hc=$(curl -s -o /dev/null -w '%{http_code}' "${AUTH[@]}" \
      "${JF_URL}/router/api/v1/system/health" || true)
[ "$hc" = "200" ] || log "WARN: platform health check returned HTTP ${hc} (continuing)"

# ----------------------------- discover services ---------------------------
if [ -z "$SERVICES" ]; then
  SERVICES=$(list_path "" 0 1 | jq -r '.files[] | select(.folder==true) | .uri | ltrimstr("/")')
  [ -n "$SERVICES" ] || die "No service folders found under ${REPO}."
fi
log "Services: $(echo $SERVICES | tr '\n' ' ')"

mkdir -p "$BASE_DIR"
grand_dl=0; grand_fail=0

# ----------------------------- per service ----------------------------------
for svc in $SERVICES; do
  # Pick date: explicit DATE, else newest date folder under the service
  if [ -n "$DATE" ]; then
    day="$DATE"
  else
    day=$(list_path "/${svc}" 0 1 \
          | jq -r '.files[] | select(.folder==true) | .uri | ltrimstr("/")' \
          | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort | tail -1 || true)
  fi
  if [ -z "${day:-}" ]; then
    log "[$svc] no date folder found; leaving existing files untouched."
    continue
  fi

  if ! files_json=$(list_path "/${svc}/${day}" 1 0 2>/dev/null); then
    log "[$svc] could not list ${svc}/${day}; existing files kept."
    continue
  fi

  ROWS=()
  while IFS= read -r line; do [ -n "$line" ] && ROWS+=("$line"); done < <(
    echo "$files_json" | jq -r '.files[] | select(.folder==false)
      | "\(.uri)\t\(.size)\t\(.sha256 // .sha2 // "")"')

  if [ "${#ROWS[@]}" -eq 0 ]; then
    log "[$svc] ${day} has no files; existing files kept."
    continue
  fi

  if [ -n "$DATE" ]; then label="pinned date"; else label="latest date"; fi
  log "[$svc] fetching ${label} ${day} — ${#ROWS[@]} file(s)..."

  # Download into a fresh staging dir, then atomically swap it in (= override)
  stage="${BASE_DIR}/.stage-${svc}.$$"
  STAGES+=("$stage")
  rm -rf "$stage"; mkdir -p "$stage"

  dl=0; fail=0
  for row in "${ROWS[@]}"; do
    IFS=$'\t' read -r uri size remote_sha <<<"$row"
    flat="${uri#/}"; flat="${flat//\//__}"      # node-1/foo.log.gz -> node-1__foo.log.gz
    out="${stage}/${day}__${flat}"
    url="${JF_URL}/artifactory/${REPO}/${svc}/${day}${uri}"
    code=$(curl -sS -L --retry "$RETRIES" --retry-delay 2 "${AUTH[@]}" \
             -w '%{http_code}' -o "$out" "$url" 2>/dev/null || echo 000)
    if [ "$code" = "200" ]; then
      if [ "$VERIFY_SHA" = "true" ] && [ -n "$remote_sha" ]; then
        ls_sha=$(sha256_of "$out")
        if [ -n "$ls_sha" ] && [ "$ls_sha" != "$remote_sha" ]; then
          log "[$svc] SHA mismatch: ${uri}"; rm -f "$out"; fail=$((fail+1)); continue
        fi
      fi
      dl=$((dl+1))
    else
      log "[$svc] download failed (HTTP ${code}): ${uri}"; rm -f "$out"; fail=$((fail+1))
    fi
    [ "$SLEEP" = "0" ] || sleep "$SLEEP"
  done

  # Only override the live folder if we actually got something
  if [ "$dl" -gt 0 ]; then
    rm -rf "${BASE_DIR:?}/${svc}"
    mv "$stage" "${BASE_DIR}/${svc}"
    log "[$svc] ${day}: stored ${dl} file(s) -> ${BASE_DIR}/${svc} (previous overwritten)."
  else
    rm -rf "$stage"
    log "[$svc] ${day}: nothing downloaded; existing files kept."
  fi
  grand_dl=$((grand_dl+dl)); grand_fail=$((grand_fail+fail))
done

log "Done. downloaded=${grand_dl} failed=${grand_fail}  ->  ${BASE_DIR}/<service>/"
[ "$grand_fail" -eq 0 ] || exit 1
