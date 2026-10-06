// Package testdb gives tests a private schema in a real PostgreSQL.
package testdb

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

// EnvVar names the variable holding the URL of the test database.
const EnvVar = "TEST_DATABASE_URL"

// New creates an empty schema and returns a database URL whose search_path
// points at it, so tests share neither tables with each other nor with real
// data. The schema is dropped when the test ends.
//
// Without TEST_DATABASE_URL the test is skipped locally and fails in CI,
// where a silent skip would hide the required duplicate-protection tests.
func New(t *testing.T) string {
	t.Helper()

	raw := os.Getenv(EnvVar)
	if raw == "" {
		const msg = EnvVar + " is not set: tests against PostgreSQL did NOT run " +
			"(start it with `docker compose up -d db`, see CLAUDE.md)"
		if os.Getenv("CI") != "" {
			t.Fatal(msg)
		}
		t.Skip(msg)
	}
	u, err := url.Parse(raw)
	if err != nil || (u.Scheme != "postgres" && u.Scheme != "postgresql") {
		t.Fatalf("%s must be a postgres:// URL", EnvVar)
	}

	suffix := make([]byte, 8)
	if _, err := rand.Read(suffix); err != nil {
		t.Fatal(err)
	}
	schema := "test_" + hex.EncodeToString(suffix)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	exec(ctx, t, raw, `CREATE SCHEMA `+schema)

	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		exec(ctx, t, raw, `DROP SCHEMA `+schema+` CASCADE`)
	})

	q := u.Query()
	q.Set("search_path", schema)
	u.RawQuery = q.Encode()
	return u.String()
}

func exec(ctx context.Context, t *testing.T, dsn, sql string) {
	t.Helper()
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		t.Fatalf("connect to %s: %v", EnvVar, err)
	}
	defer conn.Close(ctx)
	if _, err := conn.Exec(ctx, sql); err != nil {
		t.Fatalf("%s: %v", sql, err)
	}
}
