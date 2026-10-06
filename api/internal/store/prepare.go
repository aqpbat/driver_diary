package store

import (
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"driverdiary/internal/trip"
)

//go:embed migrations/*.sql
var migrationFiles embed.FS

// prepareLockKey is the advisory lock that serialises migrations and seeding
// across every instance pointed at the same database ("drvdiary" in ASCII).
const prepareLockKey int64 = 0x6472766469617279

// prepare migrates and seeds under a session-level advisory lock, so two
// replicas starting together do the work once: the second one waits, then
// finds everything already in place.
func (s *Store) prepare(ctx context.Context, seedFile string) error {
	ctx, cancel := context.WithTimeout(ctx, prepareTimeout)
	defer cancel()

	// The lock belongs to the session, so everything runs on one connection.
	conn, err := s.pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("acquire connection: %w", err)
	}
	defer conn.Release()

	if _, err := conn.Exec(ctx, `SELECT pg_advisory_lock($1)`, prepareLockKey); err != nil {
		return fmt.Errorf("take migration lock: %w", err)
	}
	defer func() {
		// Unlock even if ctx is already cancelled. If that fails, close the
		// connection: ending the session is what releases the lock for sure.
		unlockCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
		defer cancel()
		if _, err := conn.Exec(unlockCtx, `SELECT pg_advisory_unlock($1)`, prepareLockKey); err != nil {
			s.log.Error("release migration lock", "error", err)
			_ = conn.Conn().Close(unlockCtx)
		}
	}()

	if err := s.migrate(ctx, conn); err != nil {
		return err
	}
	return s.seed(ctx, conn, seedFile)
}

func (s *Store) migrate(ctx context.Context, conn *pgxpool.Conn) error {
	_, err := conn.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (
		version    TEXT        PRIMARY KEY,
		applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
	)`)
	if err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	rows, err := conn.Query(ctx, `SELECT version FROM schema_migrations`)
	if err != nil {
		return fmt.Errorf("read applied migrations: %w", err)
	}
	versions, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		return fmt.Errorf("read applied migrations: %w", err)
	}
	applied := make(map[string]bool, len(versions))
	for _, v := range versions {
		applied[v] = true
	}

	// ReadDir sorts by file name, and the names start with a number.
	entries, err := migrationFiles.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("list migrations: %w", err)
	}
	for _, e := range entries {
		name := e.Name()
		if applied[name] {
			continue
		}
		sql, err := migrationFiles.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", name, err)
		}
		// The migration and its record commit together or not at all.
		err = pgx.BeginFunc(ctx, conn, func(tx pgx.Tx) error {
			if _, err := tx.Exec(ctx, string(sql)); err != nil {
				return err
			}
			_, err := tx.Exec(ctx, `INSERT INTO schema_migrations (version) VALUES ($1)`, name)
			return err
		})
		if err != nil {
			return fmt.Errorf("apply migration %s: %w", name, err)
		}
		s.log.Info("migration applied", "version", name)
	}
	return nil
}

// seed loads the seed file into an empty trips table. A table that already
// has rows is left alone, so trips added through the API survive restarts.
func (s *Store) seed(ctx context.Context, conn *pgxpool.Conn, path string) error {
	if path == "" {
		return nil
	}
	var empty bool
	if err := conn.QueryRow(ctx, `SELECT NOT EXISTS (SELECT 1 FROM trips)`).Scan(&empty); err != nil {
		return fmt.Errorf("check for existing trips: %w", err)
	}
	if !empty {
		return nil
	}

	trips, err := readSeed(path)
	if err != nil {
		return err
	}
	err = pgx.BeginFunc(ctx, conn, func(tx pgx.Tx) error {
		for _, t := range trips {
			_, err := tx.Exec(ctx,
				`INSERT INTO trips (`+tripColumns+`) VALUES ($1, $2, $3, $4, $5, $6)`,
				t.ID, t.Start, t.End, t.Amount, t.Commission, string(t.Payment))
			if err != nil {
				return fmt.Errorf("trip %q: %w", t.ID, err)
			}
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("seed from %s: %w", path, err)
	}
	s.log.Info("database seeded", "file", path, "trips", len(trips))
	return nil
}

// readSeed parses the seed file and refuses it as a whole if any trip is
// invalid or an id repeats: a half-loaded seed would give wrong summaries.
func readSeed(path string) ([]trip.Trip, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read seed file: %w", err)
	}
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var trips []trip.Trip
	if err := dec.Decode(&trips); err != nil {
		return nil, fmt.Errorf("parse seed file %s: %w", path, err)
	}
	if _, err := dec.Token(); err != io.EOF {
		return nil, fmt.Errorf("parse seed file %s: unexpected data after the list", path)
	}

	seen := make(map[string]bool, len(trips))
	for i, t := range trips {
		if errs := trip.Validate(t); errs != nil {
			return nil, fmt.Errorf("seed file %s: trip #%d (id %q) is invalid: %v", path, i+1, t.ID, errs)
		}
		if seen[t.ID] {
			return nil, fmt.Errorf("seed file %s: trip #%d repeats id %q", path, i+1, t.ID)
		}
		seen[t.ID] = true
	}
	return trips, nil
}
