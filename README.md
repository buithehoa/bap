# bap

[![CI](https://github.com/buithehoa/bap/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/buithehoa/bap/actions/workflows/ci.yml)

Rails 8.1.4.1 · Ruby 4.0.10 · PostgreSQL 17 · Hotwire + Tailwind · Solid Queue/Cache/Cable · deployed on Fly.io (`sin`).

## Local development

Postgres always runs in Docker (`compose.yaml`). Rails can run on the host or in Docker.

### Option A: Rails on the host

```bash
rvm install 4.0.10        # .ruby-version pins ruby-4.0.10
bundle install
docker compose up -d db   # Postgres 17 on localhost:5432 (postgres/postgres)
bin/setup                 # installs gems, prepares the DB, starts bin/dev
```

Seeds create a dev user: `dev@example.com` / `password` (`bin/rails db:seed`).

`config/database.yml` reads `DB_HOST`, `DB_PORT`, `DB_USER` and `DB_PASSWORD`. If something else is on port 5432, run with `DB_PORT=5433 docker compose up -d db` and export `DB_PORT=5433`.

### Option B: everything in Docker

```bash
bin/docker-dev up --build                       # db + web (http://localhost:3000) + tailwind watcher
bin/docker-dev run --rm web bin/rails db:seed
bin/docker-dev run --rm web bin/rails test
bin/docker-dev run --rm web bin/rails console
bin/docker-dev down
```

`bin/docker-dev` is `docker compose` run with your UID and GID, so files the containers write (`tmp/`, `log/`, `app/assets/builds`) stay owned by you. After changing the `Gemfile`, run `bin/docker-dev run --rm web bundle install`.

### Tests and checks (same as CI)

```bash
bin/rails test
bin/rails test:system   # headless Chrome on the host (the dev Docker image has no Chrome)
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

## Deploying to Fly.io

Configuration is in `fly.toml`: app `bap`, region `sin`, one `shared-cpu-1x` machine with 256MB and 512MB swap. The image is built from `Dockerfile`. `bin/docker-entrypoint` runs `db:prepare` on boot.

Production uses four databases on one Postgres cluster: `bap` for the app plus `bap_cache`, `bap_queue` and `bap_cable`. `fly postgres attach` sets only `DATABASE_URL`. `config/database.yml` builds the other three URLs from it by adding a suffix to the database name. You can override them with `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` and `CABLE_DATABASE_URL`.

Solid Queue runs as threads inside Puma (`SOLID_QUEUE_IN_PUMA=true`, `SOLID_QUEUE_MODE=async`), so there's no separate worker machine. Auto-stop is turned off so that jobs keep running.

### First deploy (one time)

```bash
# 1. App (fails if the name `bap` is taken: change `app` in fly.toml and the commands below)
fly apps create bap

# 2. Unmanaged Fly Postgres: single node, smallest VM, 1GB volume
fly postgres create --name bap-db --region sin --initial-cluster-size 1 \
  --vm-size shared-cpu-1x --volume-size 1

# 3. Attach: creates database `bap` and user `bap`, and sets DATABASE_URL on the app
fly postgres attach bap-db --app bap

# 4. The attached user can't CREATE DATABASE, so create the Solid databases once:
fly postgres connect -a bap-db
#   CREATE DATABASE bap_cache OWNER bap;
#   CREATE DATABASE bap_queue OWNER bap;
#   CREATE DATABASE bap_cable OWNER bap;
#   \q

# 5. Secrets and deploy
fly secrets set RAILS_MASTER_KEY="$(cat config/master.key)" --app bap --stage
fly deploy --ha=false   # one machine; the default (--ha=true) creates two
```

If you skip step 4, the first boot fails with `permission denied to create database`. If it fails with `permission denied for schema public` instead, the attached user doesn't own `bap`. Fix it in `fly postgres connect -a bap-db` with `ALTER DATABASE bap OWNER TO bap;`.

Don't push to `main` before step 5 and the `FLY_API_TOKEN` secret below are done, or the CI deploy job fails.

Unmanaged Fly Postgres is not covered by Fly support. Backups, upgrades and recovery are your job (see `fly postgres backup --help`).

### Continuous deployment

Every push to `main` runs CI (`.github/workflows/ci.yml`). If all jobs pass, the `deploy` job runs `flyctl deploy --remote-only --ha=false`. To set it up:

```bash
fly tokens create deploy --app bap   # copy the token
gh secret set FLY_API_TOKEN          # paste it
```

### Not configured yet

- **Email:** no SMTP is set up in production, so password-reset emails fail with `ECONNREFUSED localhost:25`. Configure `config.action_mailer.smtp_settings` in `config/environments/production.rb`. Mailer links use `APP_HOST`, which defaults to `bap.fly.dev`.
- **Memory:** idle is about 130MB and about 160MB under light load in a 256MB container, measured locally. If Fly shows OOM restarts, raise `memory` in `fly.toml` to `512mb`.
