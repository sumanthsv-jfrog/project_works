JFrog Artifactory: Cached Local Repository Creator
This script automates the creation of a corresponding Local Repository for a set of existing Remote Repositories in a Artifactory instance. This is useful for creating specific local caches or mirrors.

Prerequisites
JFrog CLI (jf): Must be installed and configured.

Configured JFrog Server: The Artifactory instance must be configured in the JFrog CLI using jf c add.

Template File (template.json): A valid Artifactory repository configuration JSON file is required. This file must use the following placeholder variables:

{{.repo-name}}

{{.package-type}}

Permissions: The JFrog server ID must be configured with credentials that have Admin privileges to create repositories.

Tools: The script requires jq and tr to be installed on the system.

Usage
./create_cached_locals_for_all_remotes.sh <server_id> <template_file> [--dry-run]

Example:
./create_cached_locals_for_all_remotes.sh shsource template.json --dry-run
./create_cached_locals_for_all_remotes.sh shsource template.json --dry-run
