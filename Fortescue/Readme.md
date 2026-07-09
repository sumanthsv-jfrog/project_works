# JFrog Artifactory Permission Reporting Scripts

Two small POSIX shell scripts that export JFrog Artifactory permission
information to CSV files for review and auditing.

| Script | Output (default) | View |
|--------|------------------|------|
| `jfrog-list-permissions.sh` | `permissions.csv` | One row per **permission target** |
| `jfrog-list-group-permissions.sh` | `group_perm.csv` | One row per **group** (per permission target) |

---

## Safety: these scripts are strictly read-only

This is important, so it is stated up front:

- **Only HTTP `GET` requests are used.** The scripts never send `POST`,
  `PUT`, `DELETE`, or `PATCH`, and never include a request body. Every call
  goes through a single helper that runs `curl` with no method flag, so it
  defaults to `GET`
- **The only things written are local files** on the machine running the
  script: the CSV output file and short-lived temporary files.

### How many API calls are made

Each script makes **`1 + N` calls**, where **N is the number of permission
targets** in Artifactory:

1. One call to list all permission targets:
   `GET /api/security/permissions`
   (this returns only the target *names*, not their contents).
2. One call per target to read its details:
   `GET /api/security/permissions/{name}`
   (repositories, groups, and users).

So if you have 25 permission targets, each script makes 26 read-only GET
requests. The group script uses the same `1 + N` pattern. This is a
property of the Artifactory V1 Security API: the list endpoint returns only
names, so the details must be fetched per target.

---

## Requirements

- A POSIX shell (`/bin/sh`) — works with dash, bash, busybox ash, etc.
- `curl`
- `jq`

Both `curl` and `jq` must be on `PATH`; each script checks and exits with a
clear message if either is missing.

An **admin** access token (or admin user) is required, because the
Artifactory Security Permissions API is admin-only.

---

## Authentication

Set these environment variables before running either script.

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

---

## Script 1 — `jfrog-list-permissions.sh`

Lists every permission target with its repositories, groups (and their
privileges), and users (and their privileges).

### Usage

```sh
./jfrog-list-permissions.sh                    # -> permissions.csv
./jfrog-list-permissions.sh -o /path/out.csv   # custom output file
./jfrog-list-permissions.sh <target-name>      # only one permission target
```

Options and overrides:

- `-o <file>` — output file path (default `permissions.csv`).
- A trailing argument limits output to a single permission target by name.

### CSV columns

```
permission_name, repositories, groups_with_privileges, users_with_privileges
```

- `repositories` — repos joined by `; `
- `groups_with_privileges` — e.g. `dev-group: read, deploy; admins: read, deploy, manage`
- `users_with_privileges` — e.g. `jsmith: read, deploy`

### Example row

```
"jfcli-user-permissions","debian-repo; jfrog-cli-local","","jfcli-user: read, deploy, annotate"
```

---

## Script 2 — `jfrog-list-group-permissions.sh`

A group-centric view: one row per group per permission target. A group that
belongs to several permission targets gets several rows, each showing the
repositories and privileges for that specific target. Rows are sorted by
group name so a group's entries stay together.

### Usage

```sh
./jfrog-list-group-permissions.sh                    # -> group_perm.csv
./jfrog-list-group-permissions.sh -o /path/out.csv   # custom output file
./jfrog-list-group-permissions.sh -g <group-name>    # only one group
```

Options and overrides:

- `-o <file>` — output file path (default `group_perm.csv`).
- `-g <group-name>` — limit output to a single group.

### CSV columns

```
groupname, permission_name, repositories, permissions
```

- `repositories` — repos of that permission target, joined by `; `
- `permissions` — that group's privileges in that permission target

### Example rows

```
"ics-admin-group","alpha-team-permissions","alpha-npm-remote","read, deploy, annotate"
"ics-admin-group","beta-team-perms","beta-docker-local; beta-generic-local","read, deploy, delete, manage"
```

---

## Progress output

While running, each script prints short progress messages to **stderr** (not
into the CSV), for example:

```
==> Connecting to https://mycompany.jfrog.io/artifactory ...
==> Found 25 permission target(s).
==> Writing CSV to permissions.csv ...
==> Done. Wrote 25 permission target(s) to permissions.csv
```

Because these go to stderr, the CSV file stays clean even if you redirect
output elsewhere.

---
