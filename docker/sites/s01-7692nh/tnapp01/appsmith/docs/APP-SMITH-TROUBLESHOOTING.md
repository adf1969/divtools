# Appsmith (tnapp01) - Troubleshooting & Notes

## Symptom: RTS repeats `ECONNREFUSED 127.0.0.1:8080`

You’ll see logs like:

- `rts ... Not able to connect to Backend server: connect ECONNREFUSED 127.0.0.1:8080`
- `rts ... Exceeded maximum retry attempts. Backend server is not running.`

### What it actually means

RTS runs inside the Appsmith container and expects the Appsmith backend to be listening on `localhost:8080`.

`ECONNREFUSED` here means: **the backend process is not running (or crashed before binding port 8080).**

### How to confirm

Run:

- `docker exec appsmith supervisorctl status`

If you see:

- `backend  FATAL  Exited too quickly`

then the backend died and RTS will never be able to connect.

### Root cause we hit on 2026-01-20

The backend start script `run-java.sh` chooses its runtime mode by inspecting `APPSMITH_DB_URL`:

- Default: Mongo mode (`/opt/appsmith/server/mongo`)
- If `APPSMITH_DB_URL` starts with `postgresql://...`: Postgres mode (`/opt/appsmith/server/pg`)

On this host/image, the container does **not** include `/opt/appsmith/server/pg`, so setting `APPSMITH_DB_URL` to a Postgres URL causes an immediate crash:

- `cd: /opt/appsmith/server/pg: No such file or directory`

### Resolution / prevention

Keep the deployment aligned with Appsmith’s documented Docker install:

- Use the single `appsmith` container
- Persist `/appsmith-stacks`
- Do **not** set `APPSMITH_DB_URL` to `postgresql://...` in the compose/env for this setup

The compose file for tnapp01 is intentionally minimal:

- [docker/sites/s01-7692nh/tnapp01/appsmith/dci-appsmith.yml](../dci-appsmith.yml)

## External PostgreSQL docs

Appsmith has documentation for external PostgreSQL (for some deployment variants). If you choose to reintroduce external DB configuration, validate first that the specific Appsmith image/version you’re running supports it end-to-end (startup runtime path, migrations, and expected environment variables).

As a general rule for this repo:

- Don’t configure Postgres as the primary Appsmith datastore unless the container image clearly supports it.
