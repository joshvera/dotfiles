---
name: gws-cli
description: Use the Google Workspace CLI to work with Gmail, Drive, Calendar, Docs, and Sheets from the local host shell.
---

# Google Workspace CLI

Use the `gws` binary directly from the host shell.

## Prerequisites

- Install with `brew install googleworkspace-cli`.
- Authenticate before use:
  - `gws auth status`
  - If unauthenticated, place your OAuth desktop client at `~/.config/gws/client_secret.json`
  - Then run `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws auth login -s drive,gmail,calendar,docs,sheets`

## Common commands

```text
gws --help
gws auth status
gws schema drive.files.list
gws drive files list --params '{"pageSize":10}'
gws gmail users messages list --params '{"userId":"me","maxResults":10}'
gws calendar events list --params '{"calendarId":"primary","maxResults":10}'
gws docs documents get --params '{"documentId":"..."}'
gws sheets spreadsheets get --params '{"spreadsheetId":"..."}'
```

## Working style

- Prefer read commands first.
- Ask for confirmation before create, send, share, upload, or delete operations.
- Keep result sets small with `pageSize`, `maxResults`, and focused IDs.
- Use `gws schema ...` to inspect request/response shapes before writing JSON payloads.
