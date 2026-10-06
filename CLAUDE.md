# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Driver shift diary" — a take-home test assignment. A server exposes a driver's trips and a per-day summary; a client shows the summary and trip list, switches days, and adds trips.

**Current state: stages 1–3 done.** The backend (`internal/trip`, `internal/store`, `internal/httpapi`, `cmd/server`) is implemented and tested; `api/Dockerfile`, `api/.dockerignore` and `api/railway.json` exist, the compose stack is verified, and the API runs on Railway at https://api-production-ab4d.up.railway.app (project `driver-diary`, services `api` and `Postgres`). CI does not exist, and `mobile/` is the untouched Flutter template. [PLAN.md](PLAN.md) (in Russian) holds the decisions, the API contract, and the task checklist — read it before implementing anything, and tick its checkboxes as tasks are completed.

The user communicates in Russian; README and PLAN are written in Russian.

## Commands

Mobile (run from `mobile/`):

```sh
flutter pub get
flutter analyze
flutter test                                  # all tests
flutter test test/path/to_test.dart           # one file
flutter test --plain-name "substring"         # one test by name
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080    # Android emulator
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Backend (run from `api/`):

```sh
go test -race ./...                                # store tests need TEST_DATABASE_URL, see below
go test -race ./internal/trip -run TestSummarize   # one test
go vet ./... && gofmt -l .
DATABASE_URL='postgres://diary:diary@localhost:5432/diary?sslmode=disable' go run ./cmd/server
```

Local stack (Postgres + API): `docker compose up --build` from the repo root → `http://localhost:8080`. `docker compose down -v` resets the database to the seed.

Tests that touch the database:

```sh
docker compose up -d db
TEST_DATABASE_URL='postgres://diary:diary@localhost:5432/diary?sslmode=disable' go test -race ./...
```

## Toolchain — versions are pinned on purpose

- Go **1.26.8** (`go.mod`: `go 1.26` + `toolchain go1.26.8`). Standard library plus exactly one module, the PostgreSQL driver `github.com/jackc/pgx/v5` (pure Go — the build stays `CGO_ENABLED=0`). Do not add other Go modules: no router, no ORM, no migration tool, no testcontainers.
- PostgreSQL **18.6** (`postgres:18.6-alpine3.24`, pinned by digest in `docker-compose.yml`; CI must use the same image).
- Flutter **3.47.5** / Dart **3.13.4**. Dart dependencies use exact versions (no `^`); `pubspec.lock` is committed.
- Docker base images: exact tag plus `@sha256:` digest.
- Node and a modern Python are not installed on this machine.

## Architecture

### Backend (`api/`)

Three layers, dependencies point inward:

- `internal/trip` — model, validation, summary calculation. Pure functions, no HTTP, no I/O, no SQL. This is where the assignment's required tests live.
- `internal/store` — PostgreSQL via `pgxpool` (`DATABASE_URL`). Embedded SQL migrations run at startup under `pg_advisory_lock`; `data/trips.json` is seeded only when the table is empty. HTTP handlers depend on a store interface, not on `pgx`.
- `internal/httpapi` — routes on the stdlib `ServeMux`, CORS, the single error envelope.

Rules that span these layers and are easy to get wrong:

- **Money is integers.** Never `float`.
- **A trip's "day" is the local date of its `start` in `APP_TZ`** (default `Asia/Almaty`), not the offset the client sent and not UTC. The server needs `import _ "time/tzdata"` because the runtime image has no zoneinfo.
- **Idempotency key is the client-supplied `id`.** `POST /api/v1/trips`: new → `201`; same `id` and same content → `200`, nothing written; same `id` with different content → `409`. "Same content" compares time *instants*, so `08:10+05:00` equals `03:10Z`. Atomicity comes from the primary key: `INSERT … ON CONFLICT(id) DO NOTHING`, then read back and compare with `trip.Equal` if nothing was inserted — never check-then-insert.
- Day boundaries have two implementations that must agree: `trip.DayOf` in Go and `(start_at AT TIME ZONE $1)::date` in SQL. Always pass `APP_TZ` as the parameter — never rely on the session time zone. `TIMESTAMPTZ` stores the instant only, so responses are re-rendered in `APP_TZ`.
- The API can start before the database is reachable (Railway has no `depends_on`): connect with retries, and `/healthz` pings the DB.
- Store and duplicate-protection tests run against a real PostgreSQL given by `TEST_DATABASE_URL`, each test in its own schema (`internal/testdb.New(t)` creates it and returns the URL). They skip when it is unset locally and must fail in CI — do not replace them with an in-memory fake.
- The runtime image is distroless (no shell); the container healthcheck is the binary's own `-healthcheck` flag. `docker-compose.yml` already depends on this and on the binary living at `/server`.
- The image carries the seed at `/data/trips.json` (`TRIPS_FILE` is set in the Dockerfile); compose mounts its own copy over it. `api/.dockerignore` is an allow-list — a new top-level directory under `api/` must be added there and to the Dockerfile's `COPY` lines.
- Railway: deployed by upload, not from GitHub — `railway up --service api` run from `api/` (the CLI lives at `~/.railway/bin/railway`). Go build artifacts are ignored in `api/.gitignore`, not the root one: the CLI misread the root pattern `/api/server` and dropped `cmd/server` from the upload. If the service is later connected to the GitHub repo, Root Directory is `api` and the config path `/api/railway.json`; the server must bind `0.0.0.0:$PORT`; `DATABASE_URL` references the Railway Postgres service.

### Mobile (`mobile/`)

Flutter app targeting Android, iOS and Web (Web doubles as the public demo).

**Feature-first Clean Architecture with `flutter_bloc`.** Layout and the full rule list are in PLAN.md §3.1; the parts that are easy to violate:

- `lib/features/<feature>/{domain,data,presentation}`, shared code in `lib/core/`, wiring in `lib/app/`.
- Dependencies point to `domain`. `domain` is pure Dart: no `flutter`, `http`, `bloc` or JSON. `presentation` never imports `data`.
- Widget → Bloc/Cubit → use case → repository interface. Widgets do not call repositories; Blocs do not see HTTP or DTOs.
- Features do not import each other; anything shared (the `Trip` entity, `Failure`/`Result`, the API client, the design system) lives in `core/`.
- Exceptions stop at the `data` layer: repositories return `Result<T>` with a `Failure`. `Result` is the project's own sealed class — no `dartz`/`fpdart`.
- Dependencies are constructed once in `app/` and passed by constructor and `RepositoryProvider`/`BlocProvider`. No `get_it`, no global singletons.
- Bloc states and events are sealed classes with `Equatable`. Blocs are tested with `bloc_test` + `mocktail`.

Other constraints:

- **No Material.** The design must be custom: `WidgetsApp` instead of `MaterialApp`, no `package:flutter/material.dart` import anywhere in `lib/`, no `Icons.*`. UI is built from the project's own tokens and components in `lib/core/design/`. The template's `main.dart` and `uses-material-design: true` still violate this and are to be replaced.
- **Dart's `DateTime.parse` drops the UTC offset** and converts to UTC. Trip times must be displayed in the driver's zone as sent by the server, not the device's zone — keep the wall-clock time from the server string.
- `AddTripCubit` generates the trip `id` once in its constructor and reuses it on every retry; regenerating it on retry defeats the server's duplicate protection.
- API base URL comes from `--dart-define=API_BASE_URL`. The Android emulator reaches the host at `10.0.2.2`; cleartext HTTP is allowed in the debug manifest only.
