# Maestro Projects

This repository contains separate Maestro test projects:

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
