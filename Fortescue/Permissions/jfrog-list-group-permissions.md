# jfrog-list-group-permissions.sh

Exports a **group-centric** view of JFrog Artifactory permissions to a CSV
file. Each row represents one **group** within one **permission target**. A
group that belongs to several permission targets gets several rows, each
showing the repositories and privileges for that specific target. Rows are
sorted by group name so a group's entries stay together.

**Default output:** `group_perm.csv`

---

## Safety: read-only

- **Only HTTP `GET` requests are used.** The script never sends `POST`, `PUT`,
  `DELETE`, or `PATCH`, and never includes a request body.
- **The only things written are local files** on the machine running the
  script: the CSV output file and short-lived temporary files.

### API calls

This script makes **`1 + N` calls**, where **N is the number of permission
targets** in Artifactory:

1. `GET /api/security/permissions` — list all permission target names.
2. `GET /api/security/permissions/{name}` — details for each target
   (repositories, groups, and users).

If you have 25 permission targets, the script makes 26 read-only GET requests.
The list endpoint returns only names, so details must be fetched per target.

---

## Requirements

- A POSIX shell (`/bin/sh`) — works with dash, bash, busybox ash, etc.
- `curl`
- `jq`

Both `curl` and `jq` must be on `PATH`; the script checks and exits with a
clear message if either is missing.

An **admin** access token (or admin user) is required, because the
Artifactory Security Permissions API is admin-only.

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
./jfrog-list-group-permissions.sh                    # -> group_perm.csv
./jfrog-list-group-permissions.sh -o /path/out.csv   # custom output file
./jfrog-list-group-permissions.sh -g <group-name>    # only one group
```

### Options

| Option | Description |
|--------|-------------|
| `-o <file>` | Output file path (default `group_perm.csv`) |
| `-g <group-name>` | Limit output to a single group (case-insensitive match) |
| `-h` | Show usage and exit |

---

## CSV columns

```
groupname, permission_name, repositories, permissions
```

| Column | Description |
|--------|-------------|
| `groupname` | Name of the group |
| `permission_name` | Permission target this row refers to |
| `repositories` | Repos of that permission target, joined by `; ` |
| `permissions` | That group's privileges in that permission target |

### Permission letters (V1 API)

`m` = manage, `d` = delete, `w` = deploy, `n` = annotate, `r` = read

### Example rows

```
"ics-admin-group","alpha-team-permissions","alpha-npm-remote","read, deploy, annotate"
"ics-admin-group","beta-team-perms","beta-docker-local; beta-generic-local","read, deploy, delete, manage"
```

---

## Progress output

While running, the script prints short progress messages to **stderr** (not
into the CSV), for example:

```
==> Connecting to https://mycompany.jfrog.io/artifactory ...
==> Found 25 permission target(s). Scanning for groups ...
==> Writing CSV to group_perm.csv ...
==> Done. Wrote 42 group row(s) to group_perm.csv
```

Because these go to stderr, the CSV file stays clean even if you redirect
output elsewhere.
