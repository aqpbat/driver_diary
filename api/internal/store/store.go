// Package store keeps trips in PostgreSQL.
package store

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"driverdiary/internal/trip"
)

const (
	defaultMaxConns     = 10
	defaultConnectWait  = 30 * time.Second
	defaultQueryTimeout = 5 * time.Second

	connectRetryPause = time.Second
	pingTimeout       = 3 * time.Second
	prepareTimeout    = time.Minute
)

// Config is what Open needs. DatabaseURL and Location are required.
type Config struct {
	DatabaseURL string
	// Location is the zone that decides which day a trip belongs to and in
	// which stored times are returned.
	Location *time.Location
	// SeedFile is a JSON file loaded into the trips table when it is empty.
	// Empty means no seeding.
	SeedFile string
	// MaxConns caps the pool. Zero means 10.
	MaxConns int32
	// ConnectWait is how long Open keeps retrying while the database is
	// unreachable. Zero means 30 seconds.
	ConnectWait time.Duration
	// QueryTimeout bounds every query on top of the caller's context. Zero
	// means 5 seconds.
	QueryTimeout time.Duration
	// Logger defaults to slog.Default().
	Logger *slog.Logger
}

// Store is a pool of connections to a migrated database.
type Store struct {
	pool         *pgxpool.Pool
	loc          *time.Location
	queryTimeout time.Duration
	log          *slog.Logger
}

// Open connects to the database, waiting for it to come up, then applies
// pending migrations and seeds the trips table if it is empty.
func Open(ctx context.Context, cfg Config) (*Store, error) {
	if cfg.Location == nil {
		return nil, errors.New("store: location is required")
	}
	if cfg.DatabaseURL == "" {
		return nil, errors.New("store: database URL is required")
	}
	if cfg.MaxConns == 0 {
		cfg.MaxConns = defaultMaxConns
	}
	if cfg.ConnectWait == 0 {
		cfg.ConnectWait = defaultConnectWait
	}
	if cfg.QueryTimeout == 0 {
		cfg.QueryTimeout = defaultQueryTimeout
	}
	if cfg.Logger == nil {
		cfg.Logger = slog.Default()
	}

	poolCfg, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("store: parse database URL: %w", err)
	}
	poolCfg.MaxConns = cfg.MaxConns

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("store: create pool: %w", err)
	}
	s := &Store{pool: pool, loc: cfg.Location, queryTimeout: cfg.QueryTimeout, log: cfg.Logger}

	if err := s.waitReady(ctx, cfg.ConnectWait); err != nil {
		pool.Close()
		return nil, fmt.Errorf("store: %w", err)
	}
	if err := s.prepare(ctx, cfg.SeedFile); err != nil {
		pool.Close()
		return nil, fmt.Errorf("store: %w", err)
	}
	return s, nil
}

// waitReady pings the database until it answers or wait runs out. The API may
// be started before the database, so the first attempts are allowed to fail.
func (s *Store) waitReady(ctx context.Context, wait time.Duration) error {
	deadline := time.Now().Add(wait)
	for attempt := 1; ; attempt++ {
		pingCtx, cancel := context.WithTimeout(ctx, pingTimeout)
		err := s.pool.Ping(pingCtx)
		cancel()
		if err == nil {
			return nil
		}
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if time.Now().Add(connectRetryPause).After(deadline) {
			return fmt.Errorf("database is not reachable after %s: %w", wait, err)
		}
		s.log.Warn("database is not ready, retrying", "attempt", attempt, "error", err)

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(connectRetryPause):
		}
	}
}

// Close releases all connections. In-flight queries are waited for.
func (s *Store) Close() {
	s.pool.Close()
}

// Ping checks that the database answers.
func (s *Store) Ping(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, s.queryTimeout)
	defer cancel()
	return s.pool.Ping(ctx)
}

const tripColumns = "id, start_at, end_at, amount, commission, payment"

// Add saves t unless a trip with the same id exists. The decision is made by
// the primary key inside a single INSERT, so concurrent calls with the same id
// cannot both create a row. The returned trip is the stored one.
func (s *Store) Add(ctx context.Context, t trip.Trip) (trip.Trip, trip.AddOutcome, error) {
	ctx, cancel := context.WithTimeout(ctx, s.queryTimeout)
	defer cancel()

	// TIMESTAMPTZ keeps microseconds. Dropping the rest up front keeps a retry
	// of a trip sent with nanoseconds equal to what was stored the first time.
	t.Start = t.Start.Truncate(time.Microsecond)
	t.End = t.End.Truncate(time.Microsecond)

	tag, err := s.pool.Exec(ctx,
		`INSERT INTO trips (`+tripColumns+`) VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (id) DO NOTHING`,
		t.ID, t.Start, t.End, t.Amount, t.Commission, string(t.Payment))
	if err != nil {
		return trip.Trip{}, 0, fmt.Errorf("insert trip: %w", err)
	}
	if tag.RowsAffected() == 1 {
		t.Start, t.End = t.Start.In(s.loc), t.End.In(s.loc)
		return t, trip.Created, nil
	}

	rows, err := s.pool.Query(ctx, `SELECT `+tripColumns+` FROM trips WHERE id = $1`, t.ID)
	if err != nil {
		return trip.Trip{}, 0, fmt.Errorf("read existing trip: %w", err)
	}
	existing, err := pgx.CollectExactlyOneRow(rows, s.scanTrip)
	if err != nil {
		return trip.Trip{}, 0, fmt.Errorf("read existing trip: %w", err)
	}
	if trip.Equal(existing, t) {
		return existing, trip.Duplicate, nil
	}
	return existing, trip.Conflict, nil
}

// ByDay returns the trips that start in [from, to), ordered by start and then
// by id. The caller computes the bounds with trip.DayBounds.
func (s *Store) ByDay(ctx context.Context, from, to time.Time) ([]trip.Trip, error) {
	ctx, cancel := context.WithTimeout(ctx, s.queryTimeout)
	defer cancel()

	rows, err := s.pool.Query(ctx,
		`SELECT `+tripColumns+` FROM trips
		 WHERE start_at >= $1 AND start_at < $2
		 ORDER BY start_at, id`,
		from, to)
	if err != nil {
		return nil, fmt.Errorf("select trips of a day: %w", err)
	}
	trips, err := pgx.CollectRows(rows, s.scanTrip)
	if err != nil {
		return nil, fmt.Errorf("select trips of a day: %w", err)
	}
	return trips, nil
}

// Days returns the days that have trips, oldest first. The zone is passed as
// a parameter so the result never depends on the session's TimeZone setting;
// it must agree with trip.DayOf.
func (s *Store) Days(ctx context.Context) ([]trip.DayCount, error) {
	ctx, cancel := context.WithTimeout(ctx, s.queryTimeout)
	defer cancel()

	rows, err := s.pool.Query(ctx,
		`SELECT to_char(day, 'YYYY-MM-DD'), n
		 FROM (
		     SELECT (start_at AT TIME ZONE $1::text)::date AS day, count(*) AS n
		     FROM trips
		     GROUP BY 1
		 ) AS d
		 ORDER BY day`,
		s.loc.String())
	if err != nil {
		return nil, fmt.Errorf("select days: %w", err)
	}
	days, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (trip.DayCount, error) {
		var d trip.DayCount
		err := row.Scan(&d.Date, &d.TripsCount)
		return d, err
	})
	if err != nil {
		return nil, fmt.Errorf("select days: %w", err)
	}
	return days, nil
}

// scanTrip reads one row of tripColumns. TIMESTAMPTZ carries no zone, so the
// times are put back into the store's location.
func (s *Store) scanTrip(row pgx.CollectableRow) (trip.Trip, error) {
	var (
		t       trip.Trip
		payment string
	)
	if err := row.Scan(&t.ID, &t.Start, &t.End, &t.Amount, &t.Commission, &payment); err != nil {
		return trip.Trip{}, err
	}
	t.Start, t.End = t.Start.In(s.loc), t.End.In(s.loc)
	t.Payment = trip.Payment(payment)
	return t, nil
}
