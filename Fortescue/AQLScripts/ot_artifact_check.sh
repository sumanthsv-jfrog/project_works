#!/usr/bin/env bash
#
# ot_artifact_check.sh
# -----------------------------------------------------------------------------
# Given a CSV of artifacts from ONE Corp repo (e.g. a Cleanup dry-run report),
# check which of those artifacts are currently CACHED in the matching OT
# smart-remote repository.
#
# How it works: it dumps the OT '<repo>-cache' inventory ONCE via AQL, builds a
# lookup set of repo-relative paths, then marks each CSV row present / absent.
# (A smart remote only caches what OT has actually pulled, so "absent" means OT
#  never downloaded it -- not necessarily that OT will never need it.)
#
# Config (environment variables): same as ot_repo_mapping.sh
#   OT_URL [required], OT_TOKEN or OT_USER+OT_PASSWORD, OT_INSECURE=1 optional
#
# Arguments:
#   -r, --repo         OT smart-remote repo key (cache queried is <repo>-cache)   [required]
#   -f, --csv          input CSV file                                             [required]
#   -o, --out          output CSV (default: <csv>.ot_check.csv)
#   -c, --path-column  path column name (e.g. "Package Path") or 1-based index
#   -p, --repo-prefix  path prefix to strip (usually the Corp repo key)
#       --header       force: first CSV line is a header (skip it)
#       --no-header    force: no header, every line is data
#       --docker       Docker mode: group by image/tag dir and report the full
#                      footprint (manifest.json + every sha256__ blob) per entry
#       --no-split     do not write the separate .yes.csv / .no.csv path lists
#
# Outputs:
#   <out>              full detail (default <csv>.ot_check.csv)
#   <out>.yes.csv      artifact paths present in OT   (one per line, unless --no-split)
#   <out>.no.csv       artifact paths absent from OT  (one per line, unless --no-split)
#
# Usage:
#   export OT_URL=https://ot.example.com/artifactory
#   export OT_TOKEN=xxxxxxxx
#   ./ot_artifact_check.sh -r ot-corp-libs -f corp-libs-local.csv \
#         -c "Package Path" -p corp-libs-local -o result.csv
# -----------------------------------------------------------------------------
set -euo pipefail

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

REPO=""; CSV=""; OUT=""; PATHCOL=""; PREFIX=""; HAS_HEADER="auto"; DOCKER="no"; SPLIT="yes"
while [ $# -gt 0 ]; do
  case "$1" in
    -r|--repo)         REPO="$2"; shift 2;;
    -f|--csv)          CSV="$2"; shift 2;;
    -o|--out)          OUT="$2"; shift 2;;
    -c|--path-column)  PATHCOL="$2"; shift 2;;
    -p|--repo-prefix)  PREFIX="$2"; shift 2;;
    --header)          HAS_HEADER="yes"; shift;;
    --no-header)       HAS_HEADER="no"; shift;;
    --docker)          DOCKER="yes"; shift;;
    --no-split)        SPLIT="no"; shift;;
    -h|--help)         usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

[ -n "$REPO" ] || { echo "ERROR: --repo is required" >&2; exit 1; }
[ -n "$CSV"  ] || { echo "ERROR: --csv is required"  >&2; exit 1; }
[ -f "$CSV"  ] || { echo "ERROR: CSV not found: $CSV" >&2; exit 1; }
: "${OT_URL:?set OT_URL, e.g. https://ot.example.com/artifactory}"
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required" >&2; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "ERROR: jq is required"   >&2; exit 1; }

BASE="${OT_URL%/}"
CACHE="${REPO}-cache"
[ -n "$OUT" ] || OUT="${CSV%.csv}.ot_check.csv"
YES_OUT="${OUT%.csv}.yes.csv"
NO_OUT="${OUT%.csv}.no.csv"
if [ "$SPLIT" = "yes" ]; then : > "$YES_OUT"; : > "$NO_OUT"; fi

CURL=(curl -fsS)
[ "${OT_INSECURE:-}" = "1" ] && CURL+=(-k)
if   [ -n "${OT_TOKEN:-}" ]; then AUTH=(-H "Authorization: Bearer ${OT_TOKEN}")
elif [ -n "${OT_USER:-}" ] && [ -n "${OT_PASSWORD:-}" ]; then AUTH=(-u "${OT_USER}:${OT_PASSWORD}")
else echo "ERROR: set OT_TOKEN, or OT_USER and OT_PASSWORD" >&2; exit 1; fi

# --- 1) dump the OT cache inventory once --------------------------------------
aql='items.find({"repo":"'"$CACHE"'","type":"file"}).include("repo","path","name")'
tmp_cache="$(mktemp)"
trap 'rm -f "$tmp_cache"' EXIT
if [ "$DOCKER" = "yes" ]; then
  # docker mode: emit  <dir>\t<full-repo-relative-path>  so files can be grouped by image/tag dir
  "${CURL[@]}" "${AUTH[@]}" -H "Content-Type: text/plain" -X POST \
    --data-binary "$aql" "${BASE}/api/search/aql" \
    | jq -r '.results[] | ((if (.path=="." or .path=="") then "" else .path end) + "\t" + (if (.path=="." or .path=="") then .name else .path + "/" + .name end))' \
    | LC_ALL=C sort -u > "$tmp_cache"
else
  "${CURL[@]}" "${AUTH[@]}" -H "Content-Type: text/plain" -X POST \
    --data-binary "$aql" "${BASE}/api/search/aql" \
    | jq -r '.results[] | (if (.path=="." or .path=="") then .name else .path + "/" + .name end)' \
    | LC_ALL=C sort -u > "$tmp_cache"
fi
n_cache=$(wc -l < "$tmp_cache" | tr -d ' ')
echo "OT cache '$CACHE' holds $n_cache file(s)." >&2

# --- 2) resolve which CSV column holds the path -------------------------------
first_line="$(head -n1 "$CSV" | tr -d '\r')"
IFS=',' read -r -a HF <<< "$first_line"
is_number(){ case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }
lower(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
trim(){ printf '%s' "$1" | sed -e 's/^[ \t"]*//' -e 's/[ \t"]*$//'; }

COLIDX=""; SKIP_HEADER="no"
if [ -n "$PATHCOL" ]; then
  if is_number "$PATHCOL"; then
    COLIDX="$PATHCOL"; [ "$HAS_HEADER" = "yes" ] && SKIP_HEADER="yes"
  else
    i=0
    for f in "${HF[@]}"; do i=$((i+1))
      [ "$(lower "$(trim "$f")")" = "$(lower "$PATHCOL")" ] && { COLIDX="$i"; break; }
    done
    [ -n "$COLIDX" ] || { echo "ERROR: column '$PATHCOL' not in header: $first_line" >&2; exit 1; }
    SKIP_HEADER="yes"
  fi
else
  i=0
  for f in "${HF[@]}"; do i=$((i+1))
    ff="$(lower "$(trim "$f")")"
    case "$ff" in
      */*)     : ;;                       # contains a slash -> it's a path (data), not a header
      *path*)  COLIDX="$i"; break;;        # header-like name -> this is the path column
    esac
  done
  if [ -n "$COLIDX" ]; then SKIP_HEADER="yes"; else COLIDX="1"; SKIP_HEADER="no"; fi
  [ "$HAS_HEADER" = "yes" ] && SKIP_HEADER="yes"
  [ "$HAS_HEADER" = "no"  ] && SKIP_HEADER="no"
fi
echo "Path column = $COLIDX ; skip header = $SKIP_HEADER ; strip prefix = '${PREFIX:-<none>}'." >&2

# --- 3) match each CSV artifact against the cache set -------------------------
if [ "$DOCKER" = "yes" ]; then
  # Docker mode: an image tag lives under <image>/<tag>/ (manifest.json + sha256__ blobs).
  # For each CSV path we take its containing directory and report EVERY cached file there.
  {
    echo "original_path,image_dir,cached_file,present_in_ot"
    awk -v col="$COLIDX" -v skip="$SKIP_HEADER" -v prefix="$PREFIX" -v repo="$REPO" -v cachefile="$tmp_cache" -v dosplit="$SPLIT" -v yesfile="$YES_OUT" -v nofile="$NO_OUT" '
      function esc(s){ gsub(/"/,"\"\"",s); return s }
      BEGIN{ FS="\x01" }                                  # never auto-split; parse manually
      FILENAME==cachefile {
        ti=index($0,"\t"); dir=substr($0,1,ti-1); full=substr($0,ti+1)
        flist[dir]=(dir in fcnt)?flist[dir] SUBSEP full : full
        fcnt[dir]++; next
      }
      {
        if (FNR==1 && skip=="yes") next
        nn=split($0, b, ",")                              # extract path column
        raw=b[col]; gsub(/\r/,"",raw); gsub(/^[ \t"]+|[ \t"]+$/,"",raw)
        p=raw; sub(/^\/+/,"",p)
        if (prefix!="" && index(p, prefix "/")==1) p=substr(p, length(prefix)+2)
        if (index(p, repo "/")==1)                p=substr(p, length(repo)+2)
        li=0; for(k=length(p);k>=1;k--){ if(substr(p,k,1)=="/"){li=k;break} }
        imgdir=(li>0)?substr(p,1,li-1):p                  # directory holding this file
        if (imgdir in fcnt) {
          m=split(flist[imgdir], arr, SUBSEP)
          for(j=1;j<=m;j++){ printf "\"%s\",\"%s\",\"%s\",YES\n", esc(raw), esc(imgdir), esc(arr[j]); files++ }
          present++
          if (dosplit=="yes") print raw >> yesfile
        } else {
          printf "\"%s\",\"%s\",\"\",NO\n", esc(raw), esc(imgdir); absent++
          if (dosplit=="yes") print raw >> nofile
        }
      }
      END { printf "SUMMARY  images_present=%d  images_absent=%d  footprint_files=%d\n", present+0, absent+0, files+0 > "/dev/stderr" }
    ' "$tmp_cache" "$CSV"
  } > "$OUT"
else
  {
    echo "original_path,repo_relative_path,present_in_ot"
    awk -F',' -v col="$COLIDX" -v skip="$SKIP_HEADER" -v prefix="$PREFIX" -v repo="$REPO" -v cachefile="$tmp_cache" -v dosplit="$SPLIT" -v yesfile="$YES_OUT" -v nofile="$NO_OUT" '
      FILENAME==cachefile { cache[$0]=1; next }           # cache file: cached paths
      { if (FNR==1 && skip=="yes") next
        raw=$col; gsub(/\r/,"",raw)
        gsub(/^[ \t"]+|[ \t"]+$/,"",raw)                  # trim spaces / quotes
        p=raw; sub(/^\/+/,"",p)                           # drop leading slash
        if (prefix!="" && index(p, prefix "/")==1) p=substr(p, length(prefix)+2)
        if (index(p, repo "/")==1)                p=substr(p, length(repo)+2)
        hit = (p in cache) ? "YES" : "NO"
        if (hit=="YES") { present++; if (dosplit=="yes") print raw >> yesfile }
        else            { absent++;  if (dosplit=="yes") print raw >> nofile }
        o=raw; gsub(/"/,"\"\"",o); q=p; gsub(/"/,"\"\"",q)
        printf "\"%s\",\"%s\",%s\n", o, q, hit
      }
      END { printf "SUMMARY  present=%d  absent=%d\n", present+0, absent+0 > "/dev/stderr" }
    ' "$tmp_cache" "$CSV"
  } > "$OUT"
fi

echo "Wrote results to $OUT" >&2
if [ "$SPLIT" = "yes" ]; then
  echo "Present artifact paths -> $YES_OUT ($(wc -l < "$YES_OUT" | tr -d ' '))" >&2
  echo "Absent  artifact paths -> $NO_OUT ($(wc -l < "$NO_OUT" | tr -d ' '))" >&2
fi