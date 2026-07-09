# jfrog-list-group-users.sh

Exports every JFrog Artifactory group and its member users to a CSV file.
Each row represents one **group**; the `usernames` column lists all members
joined by `; `. Rows are sorted alphabetically by group name.

**Default output:** `group_users.csv`

---

## Safety: read-only

- **Only HTTP `GET` requests are used.** The script never sends `POST`, `PUT`,
  `DELETE`, or `PATCH`, and never includes a request body.
- **The only things written are local files** on the machine running the
  script: the CSV output file and short-lived temporary files.

### API calls

This script makes **`1 + G` calls**, where **G is the number of groups** in
Artifactory:

1. `GET /api/security/groups` — list all group names.
2. `GET /api/security/groups/{name}?includeUsers=true` — members of each
   group.

The `includeUsers=true` parameter has been supported since Artifactory 6.13.

If you have 50 groups, the script makes 51 read-only GET requests.

---

## Requirements

- A POSIX shell (`/bin/sh`) — works with dash, bash, busybox ash, etc.
- `curl`
- `jq`

Both `curl` and `jq` must be on `PATH`; the script checks and exits with a
clear message if either is missing.

An **admin** access token (or admin user) is required, because the
Artifactory Security Groups API is admin-only.

---

## Authentication

Set these environment variables before running.

`JFROG_URL` is always required (point it at the Artifactory base URL,
usually ending in `/artifactory`):

```sh
export JFROG_URL="https://mycompany.jfrog.io/artifactory"
```

Then provide credentials in **one** of two ways.

Access token (recommended):

```sh
export JFROG_TOKEN="<admin-access-token>"
```

Or basic auth (username + password or API key):

```sh
export JFROG_USER="admin"
export JFROG_PASS="<password-or-api-key>"
```

If a token is set it is used; otherwise the user/password pair is used.

You can also set a default output path via `JFROG_CSV_OUT` (overridden by
`-o`).

---

## Usage

```sh
./jfrog-list-group-users.sh                    # -> group_users.csv
./jfrog-list-group-users.sh -o /path/out.csv   # custom output file
./jfrog-list-group-users.sh -g <group-name>    # only one group
```

### Options

| Option | Description |
|--------|-------------|
| `-o <file>` | Output file path (default `group_users.csv`) |
| `-g <group-name>` | Limit output to a single group (exact name match) |
| `-h` | Show usage and exit |

---

## CSV columns

```
groupname, usernames
```

| Column | Description |
|--------|-------------|
| `groupname` | Name of the group |
| `usernames` | Member usernames joined by `; ` (empty if the group has no members) |

### Example rows

```
"developers","alice; bob; carol"
"ics-admin-group","admin; svc-deploy"
"readers",""
```

---

## Progress output

While running, the script prints short progress messages to **stderr** (not
into the CSV), for example:

```
==> Connecting to https://mycompany.jfrog.io/artifactory ...
==> Found 50 group(s). Fetching members ...
==> Writing CSV to group_users.csv ...
==> Done. Wrote 50 group(s) to group_users.csv
```

Because these go to stderr, the CSV file stays clean even if you redirect
output elsewhere.
