# decide-waiver-requests.sh

Approve or reject JFrog Curation **waiver requests** in bulk from a CSV file.

## Usage

```bash
./decide-waiver-requests.sh <JFROG_URL> <JFROG_TOKEN> [input.csv] [options]
```

Run `./decide-waiver-requests.sh -h` for built-in help.

## Input CSV

```csv
id,status
1429,approved
6,rejected
10,approved,No exploitable path in our usage.,7
```

| Column | Required | Description |
|--------|----------|-------------|
| `id` | yes | Waiver request ID (from `list-waivers.sh` `id` column) |
| `status` | yes | `approved` or `rejected` (`approve` / `reject` also accepted) |
| `justification` | no | Per-row reason; uses script defaults if omitted |
| `duration_days` | no | Waiver length for approvals only (default: `--duration-days`, usually `3`) |

Lines starting with `#` and a header row (`id,status`) are skipped.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--duration-days <n>` | `3` | Default approval duration |
| `--approve-justification <text>` | Security review approval message | Default for approved rows |
| `--reject-justification <text>` | Security review rejection message | Default for rejected rows |
| `--dry-run` | off | Print payloads without calling the API |

## Examples

```bash
# Approve/reject rows in waiver-decisions.csv
./decide-waiver-requests.sh "$JFROG_URL" "$JFROG_TOKEN"

# Custom file and 7-day approvals
./decide-waiver-requests.sh "$JFROG_URL" "$JFROG_TOKEN" decisions.csv --duration-days 7

# Build decisions from pending waivers (approve all listed ids)
./list-waivers.sh "$JFROG_URL" "$JFROG_TOKEN" --status pending \
  | tail -n +2 | cut -d, -f5 | sed 's/$/,approved/' > waiver-decisions.csv

# Preview API payloads
./decide-waiver-requests.sh "$JFROG_URL" "$JFROG_TOKEN" waiver-decisions.csv --dry-run
```

## API

- Endpoint: `POST {JFROG_URL}/xray/api/v1/curation/waiver_requests/{id}/decision`
- Approved payload includes `status`, `justification`, and `duration_days`
- Rejected payload includes `status` and `justification` only

## Related scripts

- [`list-waivers.sh`](list-waivers.md) — list pending/approved/rejected waivers and get IDs
- [`add-label-packages.sh`](add-label-packages.md) — assign approved waiver packages to a catalog label

## Flow

- [Approve / reject waiver flow](approve-reject-waivers-flow.md)
