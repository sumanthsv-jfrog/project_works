# Log_collection.sh

Bash script that mirrors the latest day of JFrog platform logs from the `jfrog-logs` Artifactory repository into a local directory. Each run replaces the previous download for each service, so the local tree always holds one batch of logs—suitable for feeding an observability uploader or ad-hoc analysis.

## Overview

The script connects to your JFrog instance, lists log files under `jfrog-logs/<service>/<YYYY-MM-DD>/`, downloads them with optional SHA-256 verification, and writes them into a flat per-service folder:

```
logs_collection/
  artifactory/    # latest day's logs (flattened filenames)
  xray/
  distribution/
```

Nested paths in the remote repo are flattened for local storage. For example, `node-1/foo.log.gz` becomes `2026-07-01__node-1__foo.log.gz`.

Downloads use a staging directory and an atomic rename, so a failed or partial run does not leave a half-updated service folder. If nothing new is downloaded for a service, existing local files are left unchanged.

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| **bash** | Uses `set -euo pipefail` |
| **curl** | HTTP client for JFrog API and downloads |
| **jq** | Parses Artifactory storage API JSON (`brew install jq` / `apt install jq`) |
| **JFROG_TOKEN** | Bearer token with **read** access to the `jfrog-logs` repository |

Optional: `sha256sum` or `shasum` for checksum verification when `VERIFY_SHA=true`.

## Quick start

```bash
export JF_URL="https://psblr.jfrog.io"
export JFROG_TOKEN="<your-access-token>"

chmod +x Log_collection.sh
./Log_collection.sh
```

Logs are written to `./logs_collection/` by default.

## Configuration

All settings are environment variables. Defaults are shown below.

| Variable | Default | Description |
|----------|---------|-------------|
| `JF_URL` | `https://psblr.jfrog.io` | JFrog platform base URL |
| `JFROG_TOKEN` | *(required)* | Bearer token for API authentication |
| `REPO` | `jfrog-logs` | Artifactory repository name |
| `BASE_DIR` | `logs_collection` | Local output root directory |
| `SERVICES` | `artifactory` | Space-separated service names to fetch. Empty string auto-discovers all top-level folders under the repo |
| `DATE` | `2026-07-01` | UTC date folder to fetch (`YYYY-MM-DD`). Empty string selects the newest date folder per service |
| `VERIFY_SHA` | `true` | Compare downloaded file SHA-256 with metadata from Artifactory when available |
| `RETRIES` | `3` | curl `--retry` count per file |
| `SLEEP` | `0` | Seconds to wait between file downloads; increase (e.g. `0.2`) if you hit HTTP 429 rate limits |

## Usage examples

**Default run** (artifactory only, pinned default date):

```bash
./Log_collection.sh
```

**Pin a specific day:**

```bash
DATE=2026-06-28 ./Log_collection.sh
```

**Use the latest available day per service:**

```bash
DATE= ./Log_collection.sh
```

**Fetch multiple services:**

```bash
SERVICES="artifactory xray" ./Log_collection.sh
```

**Auto-discover all services under the repo:**

```bash
SERVICES= ./Log_collection.sh
```

**Custom output directory:**

```bash
BASE_DIR=/var/log/jfrog ./Log_collection.sh
```

**Combine options:**

```bash
DATE=2026-06-28 SERVICES="artifactory xray distribution" BASE_DIR=/tmp/jfrog-logs ./Log_collection.sh
```

## How it works

1. **Health check** — Optionally warns if the platform health endpoint does not return HTTP 200; the script continues anyway.
2. **Service discovery** — Uses the Artifactory storage API to list folders under `jfrog-logs`, or uses the `SERVICES` you provide.
3. **Date selection** — For each service, uses `DATE` if set, otherwise picks the newest `YYYY-MM-DD` folder.
4. **File listing** — Deep-lists all files under `<service>/<date>/`.
5. **Staging download** — Downloads into `BASE_DIR/.stage-<service>.<pid>/`, verifies SHA-256 when enabled, and retries failed requests.
6. **Atomic swap** — If at least one file succeeded, removes `BASE_DIR/<service>/` and moves the staging dir into place. Otherwise keeps the existing folder and removes the staging dir.
7. **Cleanup** — Staging directories are removed on exit via a trap handler.

## Output and logging

- Progress and warnings go to **stderr** with timestamps (`HH:MM:SS`).
- A summary line reports total downloaded and failed files.
- Exit code **0** when all attempted downloads succeed.
- Exit code **1** if any download or checksum verification failed, or if required configuration/tools are missing.

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `JFROG_TOKEN is not set` | Export a valid token before running |
| `curl is required` / `jq is required` | Install missing dependencies |
| `No service folders found` | Wrong `REPO`, token lacks access, or repo is empty |
| `[service] no date folder found` | No `YYYY-MM-DD` folder under that service; existing local files kept |
| `SHA mismatch` | Corrupt or truncated download; file is removed and counted as failed |
| `download failed (HTTP 429)` | Rate limited; set `SLEEP=0.2` or higher |
| `WARN: platform health check returned HTTP ...` | Instance may be degraded; log fetch may still work |

## Security notes

- Do not commit `JFROG_TOKEN` to version control. Prefer environment variables or a secrets manager.
- The token needs read-only access to the log repository; use the narrowest scope that satisfies that.

## Related layout in Artifactory

Remote structure (conceptual):

```
jfrog-logs/
  artifactory/
    2026-07-01/
      <node-or-path>/...
  xray/
    2026-07-01/
      ...
  distribution/
    2026-07-01/
      ...
```

Local mirror after a successful run:

```
logs_collection/
  artifactory/
    2026-07-01__<flattened-remote-path>
  xray/
    ...
```
