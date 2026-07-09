JFrog Artifactory: Copy Remote Cache to Local Mirror Script
This script automates the process of copying artifacts from the internal cache of every Remote Repository to a corresponding, pre-existing Local Repository (or dedicated mirror) within a Artifactory instance. This is typically used to persist a local copy of dependencies resolved from remotes.

Prerequisites
JFrog CLI (jf): Must be installed and configured.

Configured JFrog Server: The Artifactory instance must be configured in the JFrog CLI using jf c add.

Local Mirrors Must Exist: For every remote repository named <remote-key>, a local repository named cached-<remote-key> must already exist on the Artifactory instance. (This script assumes they were created by a preceding script, like the "Cached Local Repository Creator").

Permissions: The JFrog server ID must be configured with credentials that have Admin privileges to perform repository copy operations.

Tools: The script requires the jq command-line JSON processor.

Usage
./copy_to_cached_locals_for_all_remotes.sh <server_id> [--dry-run]

Example:
./copy_to_cached_locals_for_all_remotes.sh shsource --dry-run
./copy_to_cached_locals_for_all_remotes.sh shsource 
