# Maestro Projects

This repository contains separate Maestro test projects. Each project folder
with a `run.sh` runner can be selected from the root runner:

- `Loopdhands/` — existing Loopdhands flows, scripts, credentials, and logs.
- `Still-Aware/` — flows, scripts, and logs for Still Aware.

Setup guides:

- [macOS](./SETUP-MAC.md)
- [Windows](./SETUP-WINDOWS.md)

Run flows from the repository root:

```sh
./run.sh loopdhands
./run.sh still-aware
```

To upload and run the Loopdhands Android flows on Maestro Cloud:

```sh
./run.sh loopdhands cloud
```

By default, this uses `Loopdhands/build/outputs/apk/loopdhands-2.6-staging.apk`
and excludes the standalone login flow while keeping it available as a
prerequisite. To run one flow instead:

```sh
./run.sh loopdhands cloud flows/food_request.yaml
```

The root `.env` must contain `MAESTRO_API_KEY`,
`LOOPDHANDS_MAESTRO_PROJECT_ID`, and `LOOPDHANDS_APP_FILE`. The Project ID and
APK path are already configured locally. Add a newly rotated Maestro API key
to `.env`; do not commit or paste it into chat. Maestro Cloud requires a Cloud
plan and uploads the APK, selected flows, and flow environment variables to
Maestro. Use dedicated test credentials for Cloud runs.

## Run Loopdhands in Maestro Cloud from GitHub Actions

The manually triggered workflow is
`.github/workflows/loopdhands-maestro-cloud.yml`. Before running it:

1. Add `loopdhands-2.6-staging.apk` as an asset to a **private GitHub Release**.
2. In repository **Settings > Secrets and variables > Actions**, add these
   secrets: `MAESTRO_API_KEY`, `LOOPDHANDS_MAESTRO_PROJECT_ID`,
   `MAILSLURP_API_KEY`, `LOOPDHANDS_EMAIL`, and `LOOPDHANDS_PASSWORD`.
   `MAILSLURP_INBOX_ID` is optional.
3. Open **Actions > Loopdhands Maestro Cloud > Run workflow**, enter the
   release tag containing the APK, and run it.

The workflow downloads the APK from that release, runs all Loopdhands flows
except the separately tagged login flow, and uses the login flow when another
flow invokes it as a prerequisite. Results and the Maestro Console link appear
in the GitHub Actions log. Maestro Cloud execution requires an active Cloud
plan.

To send a run report for any selected project to Teams, create a Teams Workflow
using **When a Teams webhook request is received**, configure it to post the
incoming Adaptive Card to a channel. Store the webhook URL in the ignored
repository-root `.env` file:

```sh
TEAMS_WEBHOOK_URL='https://your-teams-workflow-webhook-url'
```

The root runner loads this local file automatically:

```sh
./run.sh loopdhands
./run.sh still-aware
```

The root runner sends the project name, each available scenario result, and
the totals. Projects that do not provide individual scenario statuses are
reported as one project-level PASS or FAIL. Add future projects by placing
their runner at `<project>/run.sh`; no Teams-specific changes are needed.
The webhook URL is kept in the ignored `.env` file and must not be committed.
If Teams delivery fails, the runner prints an error and exits nonzero if the
project run itself succeeded.

The Loopdhands default run excludes the standalone `login.yaml` scenario;
other flows can still run login as a prerequisite. To run login by itself,
target it explicitly with `./run.sh loopdhands flows/login.yaml`.

To run one flow, pass its path relative to the selected project:

```sh
./run.sh loopdhands flows/login.yaml
./run.sh still-aware flows/example.yaml
```

For compatibility, `./run.sh` and `./run.sh flows/login.yaml` continue to run
Loopdhands flows. Loopdhands credentials stay in `Loopdhands/.env`; `.env`
files and generated logs are excluded from Git.
