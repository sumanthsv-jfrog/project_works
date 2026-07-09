#!/usr/bin/env bash
#
# ot_repo_mapping.sh
# -----------------------------------------------------------------------------
# Runs against an OT Artifactory instance. Lists every REMOTE repository, reads
# the URL each one points to, and derives the source ("Corp") repository name
# from that URL (the last path segment).
#
# Output CSV columns:
#   ot_repo,package_type,remote_url,smart_remote,corp_repo
#     ot_repo       - repo key on OT (this is what you pass to script 2 --repo)
#     smart_remote  - "yes" if the URL path contains /artifactory/ (points at
#                     another Artifactory), "no" for external mirrors etc.
#     corp_repo     - repo key on Corp the remote points at (use as --repo-prefix)
#
# Config (environment variables):
#   OT_URL        Base URL incl. context, e.g. https://ot.example.com/artifactory   [required]
#   OT_TOKEN      Access token (Bearer)                                             [preferred]
#   OT_USER       ) basic-auth alternative to OT_TOKEN
#   OT_PASSWORD   )
#   OT_INSECURE   set to 1 to skip TLS verification (self-signed certs)
#
# Usage:
#   export OT_URL=https://ot.example.com/artifactory
#   export OT_TOKEN=xxxxxxxx
#   ./ot_repo_mapping.sh                       # print to stdout
#   ./ot_repo_mapping.sh -o mapping.csv        # write to file
#   ./ot_repo_mapping.sh --corp-host corp.example.com   # only remotes on that host
# -----------------------------------------------------------------------------
set -euo pipefail

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

OUT=""
CORP_HOST=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--out)       OUT="$2"; shift 2;;
    --corp-host)    CORP_HOST="$2"; shift 2;;
    -h|--help)      usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

: "${OT_URL:?set OT_URL, e.g. https://ot.example.com/artifactory}"
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required" >&2; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "ERROR: jq is required"   >&2; exit 1; }

BASE="${OT_URL%/}"

CURL=(curl -fsS)
[ "${OT_INSECURE:-}" = "1" ] && CURL+=(-k)
if   [ -n "${OT_TOKEN:-}" ]; then AUTH=(-H "Authorization: Bearer ${OT_TOKEN}")
elif [ -n "${OT_USER:-}" ] && [ -n "${OT_PASSWORD:-}" ]; then AUTH=(-u "${OT_USER}:${OT_PASSWORD}")
else echo "ERROR: set OT_TOKEN, or OT_USER and OT_PASSWORD" >&2; exit 1; fi

json="$("${CURL[@]}" "${AUTH[@]}" "${BASE}/api/repositories?type=remote")"

write() { if [ -n "$OUT" ]; then printf '%s\n' "$1" >>"$OUT"; else printf '%s\n' "$1"; fi; }
[ -n "$OUT" ] && : >"$OUT"
write "ot_repo,package_type,remote_url,smart_remote,corp_repo"

printf '%s' "$json" | jq -r '.[] | [.key, (.packageType // ""), (.url // "")] | @tsv' |
while IFS=$'\t' read -r key ptype url; do
  # split the URL into host + path
  rest="${url#*://}"                 # strip scheme
  host="${rest%%/*}"                 # host[:port]
  if [ "$rest" = "$host" ]; then path=""; else path="/${rest#*/}"; fi
  path="${path%/}"                   # drop trailing slash
  corp_repo="${path##*/}"            # last path segment
  case "/$path/" in *"/artifactory/"*) smart="yes";; *) smart="no";; esac
  if [ -n "$CORP_HOST" ] && [ "$host" != "$CORP_HOST" ]; then continue; fi
  write "$(printf '%s,%s,%s,%s,%s' "$key" "$ptype" "$url" "$smart" "$corp_repo")"
done

[ -n "$OUT" ] && echo "Wrote mapping to $OUT" >&2 || true
