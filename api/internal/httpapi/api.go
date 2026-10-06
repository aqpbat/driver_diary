// Package httpapi exposes the diary over HTTP: routes, CORS and the single
// error format. It knows the store only through the Store interface.
package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"driverdiary/internal/trip"
)

// Store is what the handlers need from the storage layer.
type Store interface {
	Ping(ctx context.Context) error
	Days(ctx context.Context) ([]trip.DayCount, error)
	ByDay(ctx context.Context, from, to time.Time) ([]trip.Trip, error)
	Add(ctx context.Context, t trip.Trip) (trip.Trip, trip.AddOutcome, error)
}

// Config is what New needs. Store and Location are required.
type Config struct {
	Store Store
	// Location decides where a day starts and ends.
	Location *time.Location
	// AllowedOrigins lists the origins allowed by CORS; "*" allows any.
	// Empty turns CORS off.
	AllowedOrigins []string
	// Logger defaults to slog.Default().
	Logger *slog.Logger
}

type api struct {
	store Store
	loc   *time.Location
	log   *slog.Logger
}

// New builds the handler for the whole API.
func New(cfg Config) http.Handler {
	if cfg.Logger == nil {
		cfg.Logger = slog.Default()
	}
	a := &api{store: cfg.Store, loc: cfg.Location, log: cfg.Logger}

	mux := http.NewServeMux()
	// Each path is registered twice: with its method, and bare. The bare
	// pattern is less specific, so it only catches the other methods and
	// answers 405 in the API's own error format instead of plain text.
	route := func(method, path string, h http.HandlerFunc) {
		mux.HandleFunc(method+" "+path, h)
		mux.HandleFunc(path, methodNotAllowed(method))
	}
	route(http.MethodGet, "/healthz", a.health)
	route(http.MethodGet, "/api/v1/days", a.listDays)
	route(http.MethodGet, "/api/v1/days/{date}", a.getDay)
	route(http.MethodPost, "/api/v1/trips", a.addTrip)
	mux.HandleFunc("/", notFound)

	return logRequests(cfg.Logger, cors(cfg.AllowedOrigins, mux))
}
