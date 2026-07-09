# add-label-packages.sh

Creates a **JFrog Catalog custom label** (if it does not exist) and assigns package versions to it using the Catalog GraphQL API.

## Usage

```bash
./add-label-packages.sh <JFROG_URL> <JFROG_TOKEN> <LABEL_NAME>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `JFROG_URL` | JFrog Platform base URL, e.g. `https://myorg.jfrog.io` |
| `JFROG_TOKEN` | Bearer access token |
| `LABEL_NAME` | Name of the catalog custom label to create or update |

## Input

By default the script reads **`packages.csv`** in the current directory.

Expected format (no header required, but a header row is skipped if present):

```csv
name,version,type
lodash,4.17.21,npm
braces,2.3.2,npm
```

Generate this file from approved waivers:

```bash
./list-waivers.sh "$JFROG_URL" "$JFROG_TOKEN" --status approved \
  | tail -n +2 | cut -d, -f1-3 | sort -u > packages.csv
```

## What it does

1. Reads package coordinates from `packages.csv`
2. Builds a GraphQL mutation → `mutation.graphql`
3. Checks whether the label already exists
4. Creates the label if missing (description defaults to `test label` in the script)
5. Executes the assign mutation to attach all listed versions to the label

## Example

```bash
./add-label-packages.sh "$JFROG_URL" "$JFROG_TOKEN" "jfrog-waiver-policy-9"
```

## Output files

| File | Purpose |
|------|---------|
| `mutation.graphql` | Generated assign mutation (useful for review or re-run) |
| `packages.csv` | Input list of packages (you provide or generate) |

## Audit mode (optional)

The script contains a `GetCAJson` function that can pull blocked packages from **JFrog Curation Audit** via `jf ca`. The default main flow uses `--from-file` behavior and reads `packages.csv` directly. To use audit export instead, adjust the script’s main flow or call `GetCAJson` before `generate_mutation`.

Requires JFrog CLI configured for your instance:

```bash
jf config add ...
```

## Requirements

- `curl`, `jq`
- `jf` (JFrog CLI) — only if using curation audit export

## API reference

- Catalog GraphQL: `POST {JFROG_URL}/catalog/api/v1/custom/graphql`
- Mutations used: `createCustomCatalogLabel`, `assignCustomCatalogLabelToPublicPackageVersions`

## Related scripts

- [`list-waivers.sh`](list-waivers.md) — export approved waivers to CSV
- [`list-label-packages.sh`](list-label-packages.md) — verify assignments
- [`remove-label-packages.sh`](remove-label-packages.md) — remove versions from the label

## Flow

- [Add packages to label flow](add-label-packages-flow.md)
