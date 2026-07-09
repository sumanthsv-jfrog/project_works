# jfrog-list-permissions.sh

Exports every JFrog Artifactory permission target to a CSV file. Each row
represents one **permission target**, with its repositories, groups (and their
privileges), and users (and their privileges).

**Default output:** `permissions.csv`

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
./jfrog-list-permissions.sh                    # -> permissions.csv
./jfrog-list-permissions.sh -o /path/out.csv   # custom output file
./jfrog-list-permissions.sh <target-name>      # only one permission target
./jfrog-list-permissions.sh -o one.csv <target-name>
```

### Options

| Option | Description |
|--------|-------------|
| `-o <file>` | Output file path (default `permissions.csv`) |
| `-h` | Show usage and exit |
| `<target-name>` | Trailing argument limits output to a single permission target by name |

---

## CSV columns

```
permission_name, repositories, groups_with_privileges, users_with_privileges
```

| Column | Description |
|--------|-------------|
| `permission_name` | Name of the permission target |
| `repositories` | Repos covered by this target, joined by `; ` |
| `groups_with_privileges` | e.g. `dev-group: read, deploy; admins: read, deploy, manage` |
| `users_with_privileges` | e.g. `jsmith: read, deploy` |

### Permission letters (V1 API)

`m` = manage, `d` = delete, `w` = deploy, `n` = annotate, `r` = read

### Example row

```
"jfcli-user-permissions","debian-repo; jfrog-cli-local","","jfcli-user: read, deploy, annotate"
```

---

## Progress output

While running, the script prints short progress messages to **stderr** (not
into the CSV), for example:

```
==> Connecting to https://mycompany.jfrog.io/artifactory ...
==> Found 25 permission target(s).
==> Writing CSV to permissions.csv ...
==> Done. Wrote 25 permission target(s) to permissions.csv
```

Because these go to stderr, the CSV file stays clean even if you redirect
output elsewhere.
