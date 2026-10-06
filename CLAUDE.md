# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Driver shift diary" — a take-home test assignment. A server exposes a driver's trips and a per-day summary; a client shows the summary and trip list, switches days, and adds trips.

**Current state: stage 1 done.** `api/internal/trip` (domain + tests) and `api/data/trips.json` exist; `internal/store`, `internal/httpapi`, `cmd/server` and the Dockerfile do not yet, and `mobile/` is the untouched Flutter template. [PLAN.md](PLAN.md) (in Russian) holds the decisions, the API contract, and the task checklist — read it before implementing anything, and tick its checkboxes as tasks are completed. Under "Backend" below, anything about the store, HTTP and deployment describes the agreed target, not existing code.

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

Backend (run from `api/`, once it exists):

```sh
go test -race ./...
go test -race ./internal/trip -run TestSummarize   # one test
go vet ./... && gofmt -l .
go run ./cmd/server
```

Local server: `docker compose up --build` from the repo root → `http://localhost:8080`.

## Toolchain — versions are pinned on purpose

- Go **1.26.8** (`go.mod`: `go 1.26` + `toolchain go1.26.8`). Standard library only — do not add third-party Go modules.
- Flutter **3.47.5** / Dart **3.13.4**. Dart dependencies use exact versions (no `^`); `pubspec.lock` is committed.
- Docker base images: exact tag plus `@sha256:` digest.
- Node and a modern Python are not installed on this machine.

## Architecture

### Backend (`api/`)

Three layers, dependencies point inward:

- `internal/trip` — model, validation, summary calculation. Pure functions, no HTTP, no I/O. This is where the assignment's required tests live.
- `internal/store` — in-memory map behind a mutex, seeded from `data/trips.json` at startup. No database, by requirement; added trips are lost on restart.
- `internal/httpapi` — routes on the stdlib `ServeMux`, CORS, the single error envelope.

Rules that span these layers and are easy to get wrong:

- **Money is integers.** Never `float`.
- **A trip's "day" is the local date of its `start` in `APP_TZ`** (default `Asia/Almaty`), not the offset the client sent and not UTC. The server needs `import _ "time/tzdata"` because the runtime image has no zoneinfo.
- **Idempotency key is the client-supplied `id`.** `POST /api/v1/trips`: new → `201`; same `id` and same content → `200`, nothing written; same `id` with different content → `409`. "Same content" compares time *instants*, so `08:10+05:00` equals `03:10Z`. The lookup and the insert must happen under one lock.
- **Single replica only** on Railway — state is in process memory, so a second replica breaks duplicate protection.
- The runtime image is distroless (no shell); the container healthcheck is the binary's own `-healthcheck` flag. `docker-compose.yml` already depends on this and on the binary living at `/server`.
- Railway: service Root Directory is `api`, the server must bind `0.0.0.0:$PORT`.

### Mobile (`mobile/`)

Flutter app targeting Android, iOS and Web (Web doubles as the public demo).

- **No Material.** The design must be custom: `WidgetsApp` instead of `MaterialApp`, no `package:flutter/material.dart` import anywhere in `lib/`, no `Icons.*`. UI is built from the project's own tokens and components in `lib/design/`. The template's `main.dart` and `uses-material-design: true` still violate this and are to be replaced.
- **Dart's `DateTime.parse` drops the UTC offset** and converts to UTC. Trip times must be displayed in the driver's zone as sent by the server, not the device's zone — keep the wall-clock time from the server string.
- The trip form generates its `id` once when opened and reuses it on every retry; regenerating it on retry defeats the server's duplicate protection.
- API base URL comes from `--dart-define=API_BASE_URL`. The Android emulator reaches the host at `10.0.2.2`; cleartext HTTP is allowed in the debug manifest only.
- State is plain `ChangeNotifier`; no state-management packages.
