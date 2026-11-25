# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, etc.) when working with code in this repository.

Setup, local dev (host or Docker), CI checks and the Fly.io first-deploy runbook are in `README.md`. Read it rather than duplicating it here. This file covers what the README doesn't.

## Environment gotchas

- **Ruby comes from rvm, not mise.** `.ruby-version` is `ruby-4.0.10`. A non-interactive tool shell can resolve `ruby`/`bundle` to a mise shim that errors with "No version is set for shim: ruby". Run Ruby commands via `bash -ilc 'cd <repo> && …'` or `/home/hoa/.rvm/rubies/ruby-4.0.10/bin/ruby`.
- **Two `gh` accounts are logged in.** The active one (`buithehoa-teamunify`) has no access to this repo and gets HTTP 403. Prefix repo commands with `GH_TOKEN="$(gh auth token --user buithehoa)"`, or switch with `gh auth switch --user buithehoa`. `git push` goes over SSH and isn't affected.
- **Every push to `main` deploys to production.** The `deploy` job in `.github/workflows/ci.yml` runs after all CI jobs pass. Use a branch + PR unless the user says to work on `main`.
- **Postgres must be running for tests:** `docker compose up -d db`.

## Commands

```bash
bin/rails test                                   # unit/integration tests
bin/rails test test/controllers/home_controller_test.rb:12   # single test by file:line
bin/rails test -n "/signed-in/"                  # tests matching a name pattern
bin/rails test:system                            # headless Chrome on the host (not in the dev Docker image)
bin/rubocop                                      # style (rubocop-rails-omakase)
bin/brakeman --no-pager; bin/bundler-audit; bin/importmap audit   # CI security scans
bin/docker-dev run --rm web bin/rails test       # tests inside the dev container
```

To mirror CI exactly, run tests with `RAILS_ENV=test DATABASE_URL=postgres://postgres:postgres@localhost:5432`.

## Architecture: things that span several files

- **Four production databases from one URL.** `config/database.yml` reads `DATABASE_URL` (set by `fly postgres attach`) for the primary DB. It builds the `cache`, `queue` and `cable` URLs from that same URL by suffixing the database name (`bap` → `bap_cache`, …). `CACHE_`/`QUEUE_`/`CABLE_DATABASE_URL` override them. The Solid gems point at these via `config/cache.yml`, `config/environments/production.rb` (`solid_queue.connects_to`) and `config/cable.yml`. Their schemas live in `db/{cache,queue,cable}_schema.rb`, not in `db/migrate`. On Fly those three databases must be created by hand (see README), because the attached user lacks CREATEDB.
- **Solid Queue runs inside Puma as threads.** `config/puma.rb` loads the `solid_queue` plugin when `SOLID_QUEUE_IN_PUMA` is set, and `SOLID_QUEUE_MODE=async` (set in `fly.toml`) avoids forking. This keeps the app on a single 256MB Fly machine; auto-stop is off so jobs keep running. Recurring jobs are in `config/recurring.yml`. Worker threads are `JOB_THREADS` and the queue DB pool is `JOB_DB_POOL` (defaults 3 and 8; `fly.toml` sets 1 and 4, with `RAILS_MAX_THREADS=2`, because the 256MB Fly Postgres runs short of memory with more connections). Production must stay at one machine (`fly deploy --ha=false`), or there will be two job supervisors.
- **Production request path:** Fly edge → Thruster on `HTTP_PORT=8080` (non-root can't bind :80 on Fly) → Puma on 3000. `bin/docker-entrypoint` runs `db:prepare` on boot; there is no `release_command`. `assume_ssl` + `force_ssl` are on, and `/up` is excluded from the SSL redirect for Fly health checks.
- **Two Dockerfiles.** `Dockerfile` is the production image (the Fly build). `Dockerfile.dev` + `compose.yaml` form the dev stack: `db`, `web` and a `css` Tailwind watcher. The source is bind-mounted and containers run as the host UID/GID, passed by `bin/docker-dev`. Dev/test DB settings come from `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASSWORD`, defaulting to the compose Postgres on localhost.
- **Authentication** is Google only, through OmniAuth (`config/initializers/omniauth.rb`, credentials from `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET`), on top of Rails 8's `generate authentication` sessions. The home page's button POSTs to `/auth/google_oauth2` with Turbo off. The callback is `SessionsController#create`, which signs in through `User.from_google!`, and the first sign-in creates the account. Users are keyed on `google_uid`, Google's stable id. `email_address` is not unique. The `Authentication` concern requires login everywhere, so public actions must call `allow_unauthenticated_access`. Signed-out requests redirect to the home page with "Sign in to continue.", and after sign-in the user returns there or lands on `/dashboard`. `HomeController#index` also calls `resume_session` so the page can show signed-in state. Admins will be a separate model with their own login, not a role on `users`. Tests sign in with `sign_in_as(user)` (`test/test_helpers/session_test_helper.rb`) or fake Google with `mock_google_auth` (`test/test_helpers/omniauth_test_helper.rb`).
- **Frontend:** importmap + Propshaft + Hotwire. Tailwind v4 compiles `app/assets/tailwind/application.css` into `app/assets/builds/`; `bin/dev` runs the watcher on the host.

## Conventions

- **Gemfile pins:** every gem uses a patch-level pessimistic pin matching `Gemfile.lock` (`gem "pg", "~> 1.7.0"`). Keep that style when adding gems. Moving to a new minor/major version means editing the constraint.
- **Ruby version** appears in `.ruby-version`, `Dockerfile`, `Dockerfile.dev` and the README badge. Change all of them together.
- `docs/superpowers/` (design/plan docs) is gitignored on purpose.
