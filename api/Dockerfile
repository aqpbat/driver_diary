# syntax=docker/dockerfile:1

# Base images are pinned by tag and digest; update both together.
FROM golang:1.26.8-alpine3.24@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c AS build

WORKDIR /src

# The toolchain in the image is the one go.mod asks for; never download another.
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOFLAGS=-mod=readonly

# Dependencies first: this layer is rebuilt only when go.mod or go.sum change.
COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY cmd ./cmd
COPY internal ./internal
RUN go build -trimpath -ldflags='-s -w' -o /out/server ./cmd/server


# Static binary only: no shell, no package manager, runs as uid 65532.
FROM gcr.io/distroless/static-debian13:nonroot@sha256:e2e927ec666bae08560abb3c55d0659eceabb657f56b6782ab500a9fc7f555e3

COPY --from=build /out/server /server
# Seed for an empty database. docker-compose mounts its own copy over this one.
COPY data/trips.json /data/trips.json

ENV PORT=8080 TRIPS_FILE=/data/trips.json
EXPOSE 8080

USER nonroot:nonroot
ENTRYPOINT ["/server"]
