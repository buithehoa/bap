# bap

[![CI](https://github.com/buithehoa/bap/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/buithehoa/bap/actions/workflows/ci.yml)
![Ruby](https://img.shields.io/badge/ruby-4.0.10-CC342D?logo=ruby)
![Rails](https://img.shields.io/badge/rails-8.1.4.1-D30001?logo=rubyonrails)
[![License](https://img.shields.io/github/license/buithehoa/bap)](LICENSE)
![Last commit](https://img.shields.io/github/last-commit/buithehoa/bap)
[![Fly.io](https://img.shields.io/badge/deployed%20on-Fly.io-8B5CF6)](https://bap.fly.dev)

## Local development

Postgres always runs in Docker (`compose.yaml`). Rails can run on the host or in Docker.

### Option A: Rails on the host

```bash
rvm install 4.0.10        # .ruby-version pins ruby-4.0.10
bundle install
docker compose up -d db   # Postgres 17 on localhost:5432 (postgres/postgres)
bin/setup                 # installs gems, prepares the DB, starts bin/dev
```

Sign in with Google. See [Google sign-in setup](#google-sign-in-setup).

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

## Google sign-in setup

Sign-in is Google only (OmniAuth, `config/initializers/omniauth.rb`). It needs a Google OAuth client:

1. In the [Google Cloud console](https://console.cloud.google.com), create a project. Under **Google Auth Platform**, set up the consent screen: audience **External**, scopes `openid` and `.../auth/userinfo.email`, then **Publish app** so it's **In production**. Don't upload a logo, which triggers brand verification.
2. Under **Clients**, create a **Web application** client with these authorized redirect URIs:
   - `http://localhost:3000/auth/google_oauth2/callback`
   - `https://bap.fly.dev/auth/google_oauth2/callback`
3. Save the client ID and secret right away, since Google shows the secret only once.

Locally, put them in the gitignored `.env`:

```
GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxx
```

`compose.yaml` passes them to the `web` container. On the host, load them first: `set -a; source .env; set +a; bin/dev`.

In production, they're Fly secrets (the leading space keeps the command out of shell history):

```bash
 fly secrets set --stage -a bap GOOGLE_CLIENT_ID='…' GOOGLE_CLIENT_SECRET='…'   # applied on the next deploy
```

Tests don't need them, because they fake Google with OmniAuth test mode (`mock_google_auth` in `test/test_helpers/omniauth_test_helper.rb`).

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

- **Database memory:** the Fly Postgres machine (`bap-db`) has 256MB, and with more connections it ran short of memory. Its health checks failed and the app got `server closed the connection unexpectedly`. So `fly.toml` keeps connections low: `RAILS_MAX_THREADS=2`, `JOB_THREADS=1`, `JOB_DB_POOL=4`, and production closes idle connections after 60s. If `fly checks list -a bap-db` still shows critical, resize it with `fly machine update <id> --vm-memory 512 -a bap-db`.
- **Memory:** idle is about 130MB and about 160MB under light load in a 256MB container, measured locally. If Fly shows OOM restarts, raise `memory` in `fly.toml` to `512mb`.
