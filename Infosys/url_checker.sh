#!/usr/bin/env bash
# Usage: ./check_registries.sh urls.txt
# Prints one line per URL:   <url><TAB><comment>
# Optional: TIMEOUT=8 ./check_registries.sh urls.txt

TIMEOUT="${TIMEOUT:-6}"
PRIVATE_RE='dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com|\.atlassian\.net|artifacts\.paketo\.io|artifactory\.rivigo\.com|cardinaldocs'

[ -r "$1" ] || { echo "Usage: $0 urls.txt" >&2; exit 1; }

# recognise the package type from the URL; echo "" if unknown
detect_type() {
  case "$1" in
    *dkr.ecr.*.amazonaws.com*|*public.ecr.aws*|*quay.io*|*registry-1.docker.io*|\
    *index.docker.io*|*gcr.io*|*ghcr.io*|*nvcr.io*|*registry.k8s.io*|\
    *registry.redhat.io*|*registry.gitlab.com*|*projects.registry.vmware.com*|\
    *releases-docker.jfrog.io*|*operator.min.io*|*:10001*|*docker*) echo "Docker" ;;
    *registry.npmjs.org*|*registry.yarnpkg.com*|*npmmirror*|*npm*) echo "npm" ;;
    *pypi.org*|*pypi.python.org*|*pythonhosted*|*/simple*) echo "PyPI" ;;
    *anaconda*|*/conda*) echo "Conda" ;;
    *nuget*) echo "NuGet" ;;
    *pub.dev*|*dartlang*) echo "Pub" ;;
    *proxy.golang.org*|*golang*) echo "Go" ;;
    *crates.io*) echo "Cargo" ;;
    *rubygems*|*/gems*) echo "Gems" ;;
    *plugins.gradle.org*) echo "Gradle" ;;
    *helm*|*kuberay-helm*) echo "Helm" ;;
    *archive.ubuntu.com*|*/apt*|*dists/*|*packages.microsoft.com*|*/debian*) echo "Debian" ;;
    *rpm*|*yum*|*redhat-stable*|*almalinux*|*/repodata*|*.repo*) echo "RPM" ;;
    *maven*|*/m2*|*maven2*|*nexus*|*sonatype*|*clojars*|*grails*|*hortonworks*|\
    *eclipse*|*spring-enterprise*|*confluent*|*jenkins-ci.org*|*pkg.jenkins.io*|\
    *shibboleth*|*catchpoint*|*magnolia-cms*) echo "Maven" ;;
    *) echo "" ;;
  esac
}

while IFS= read -r line || [ -n "$line" ]; do
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  url="${line%%[[:space:]]*}"                       # first token = the URL
  case "$url" in *://*) full="$url" ;; *) full="https://$url" ;; esac
  host="${full#*://}"; host="${host%%/*}"; host="${host%%:*}"
  lc="$(printf '%s' "$full" | tr '[:upper:]' '[:lower:]')"

  code=$(curl -sS -A "Mozilla/5.0" -m "$TIMEOUT" -L -o /dev/null \
         -w '%{http_code}' "$full" 2>/dev/null)
  cx=$?
  type="$(detect_type "$lc")"

  if printf '%s' "$host" | grep -Eq "$PRIVATE_RE"; then
    comment="its a private registry"
  elif [ "$cx" -ne 0 ]; then
    comment="Unable to access the registry"
  elif [ "$code" = "401" ]; then
    comment="its a private registry"
  elif printf '%s' "$code" | grep -Eq '^(2|3)'; then
    if [ -n "$type" ]; then
      comment="Valid $type repository"
    else
      comment="May be Generic repository might help."
    fi
  else
    comment="Not a valid registry"
  fi

  printf '%s,%s\n' "$url" "$comment"
done < "$1"