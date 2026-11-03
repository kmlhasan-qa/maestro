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
