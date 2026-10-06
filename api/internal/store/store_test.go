package store_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
	_ "time/tzdata"

	"github.com/jackc/pgx/v5"

	"driverdiary/internal/store"
	"driverdiary/internal/testdb"
	"driverdiary/internal/trip"
)

const seedFile = "../../data/trips.json"

func almaty(t *testing.T) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation("Asia/Almaty")
	if err != nil {
		t.Fatal(err)
	}
	return loc
}

func mustTime(t *testing.T, s string) time.Time {
	t.Helper()
	v, err := time.Parse(time.RFC3339Nano, s)
	if err != nil {
		t.Fatal(err)
	}
	return v
}

func open(t *testing.T, dsn, seed string) *store.Store {
	t.Helper()
	s, err := store.Open(context.Background(), store.Config{
		DatabaseURL: dsn,
		Location:    almaty(t),
		SeedFile:    seed,
		MaxConns:    4,
	})
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(s.Close)
	return s
}

// rawConn is a plain connection into the test schema, for looking at what the
// store actually wrote.
func rawConn(t *testing.T, dsn string) *pgx.Conn {
	t.Helper()
	conn, err := pgx.Connect(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close(context.Background()) })
	return conn
}

func count(t *testing.T, conn *pgx.Conn, table string) int {
	t.Helper()
	var n int
	if err := conn.QueryRow(context.Background(), `SELECT count(*) FROM `+table).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func seedTrips(t *testing.T) []trip.Trip {
	t.Helper()
	raw, err := os.ReadFile(seedFile)
	if err != nil {
		t.Fatal(err)
	}
	var trips []trip.Trip
	if err := json.Unmarshal(raw, &trips); err != nil {
		t.Fatal(err)
	}
	return trips
}

func newTrip(t *testing.T) trip.Trip {
	return trip.Trip{
		ID:         "new-1",
		Start:      mustTime(t, "2026-10-03T08:10:00+05:00"),
		End:        mustTime(t, "2026-10-03T08:42:00+05:00"),
		Amount:     2400,
		Payment:    trip.Card,
		Commission: 360,
	}
}

func TestAdd(t *testing.T) {
	dsn := testdb.New(t)
	s := open(t, dsn, "")
	conn := rawConn(t, dsn)
	ctx := context.Background()
	tr := newTrip(t)

	got, outcome, err := s.Add(ctx, tr)
	if err != nil {
		t.Fatal(err)
	}
	if outcome != trip.Created || !trip.Equal(got, tr) {
		t.Fatalf("first Add = %+v, %v; want the trip, Created", got, outcome)
	}

	got, outcome, err = s.Add(ctx, tr)
	if err != nil {
		t.Fatal(err)
	}
	if outcome != trip.Duplicate || !trip.Equal(got, tr) {
		t.Errorf("repeated Add = %+v, %v; want the trip, Duplicate", got, outcome)
	}

	// The same instants written with another offset are the same trip.
	shifted := tr
	shifted.Start = mustTime(t, "2026-10-03T03:10:00Z")
	shifted.End = mustTime(t, "2026-10-03T06:42:00+03:00")
	if _, outcome, err = s.Add(ctx, shifted); err != nil || outcome != trip.Duplicate {
		t.Errorf("Add in another offset = %v, %v; want Duplicate", outcome, err)
	}

	changed := tr
	changed.Amount = 9999
	got, outcome, err = s.Add(ctx, changed)
	if err != nil {
		t.Fatal(err)
	}
	if outcome != trip.Conflict || !trip.Equal(got, tr) {
		t.Errorf("Add with another amount = %+v, %v; want the original trip, Conflict", got, outcome)
	}

	if n := count(t, conn, "trips"); n != 1 {
		t.Errorf("%d rows in trips, want 1", n)
	}
	var amount int64
	if err := conn.QueryRow(ctx, `SELECT amount FROM trips WHERE id = $1`, tr.ID).Scan(&amount); err != nil {
		t.Fatal(err)
	}
	if amount != tr.Amount {
		t.Errorf("stored amount = %d, want %d: a conflicting Add changed the row", amount, tr.Amount)
	}
}

// PostgreSQL keeps microseconds; a retry carrying nanoseconds must still be
// recognised as the same trip.
func TestAddSubMicrosecondRetry(t *testing.T) {
	s := open(t, testdb.New(t), "")
	ctx := context.Background()
	tr := newTrip(t)
	tr.Start = mustTime(t, "2026-10-03T08:10:00.123456789+05:00")

	if _, outcome, err := s.Add(ctx, tr); err != nil || outcome != trip.Created {
		t.Fatalf("first Add = %v, %v; want Created", outcome, err)
	}
	if _, outcome, err := s.Add(ctx, tr); err != nil || outcome != trip.Duplicate {
		t.Errorf("repeated Add = %v, %v; want Duplicate", outcome, err)
	}
}

func TestAddConcurrent(t *testing.T) {
	dsn := testdb.New(t)
	s := open(t, dsn, "")
	tr := newTrip(t)

	const workers = 50
	outcomes := make([]trip.AddOutcome, workers)
	errs := make([]error, workers)
	start := make(chan struct{})
	var wg sync.WaitGroup
	for i := range workers {
		wg.Go(func() {
			<-start
			_, outcomes[i], errs[i] = s.Add(context.Background(), tr)
		})
	}
	close(start)
	wg.Wait()

	var created, duplicate int
	for i := range workers {
		if errs[i] != nil {
			t.Fatalf("worker %d: %v", i, errs[i])
		}
		switch outcomes[i] {
		case trip.Created:
			created++
		case trip.Duplicate:
			duplicate++
		}
	}
	if created != 1 || duplicate != workers-1 {
		t.Errorf("created %d, duplicate %d; want 1 and %d", created, duplicate, workers-1)
	}
	if n := count(t, rawConn(t, dsn), "trips"); n != 1 {
		t.Errorf("%d rows in trips, want 1", n)
	}
}

func TestSeedAndByDay(t *testing.T) {
	s := open(t, testdb.New(t), seedFile)
	loc := almaty(t)
	ctx := context.Background()

	// 2026-10-01 ends with a trip at 23:55 that finishes after midnight;
	// 2026-10-02 starts with a trip at 00:05.
	wantIDs := map[string][]string{
		"2026-10-01": {"t-1001", "t-1002", "t-1003", "t-1004", "t-1005", "t-1006"},
		"2026-10-02": {"t-2001", "t-2002", "t-2003", "t-2004", "t-2005", "t-2006"},
		"2026-10-03": nil,
	}
	for date, want := range wantIDs {
		from, to, err := trip.DayBounds(date, loc)
		if err != nil {
			t.Fatal(err)
		}
		trips, err := s.ByDay(ctx, from, to)
		if err != nil {
			t.Fatal(err)
		}
		var got []string
		for _, tr := range trips {
			got = append(got, tr.ID)
		}
		if strings.Join(got, ",") != strings.Join(want, ",") {
			t.Errorf("%s: trips %v, want %v", date, got, want)
		}
	}

	// Times come back in the store's zone, not in UTC or the host's zone.
	from, to, _ := trip.DayBounds("2026-10-01", loc)
	trips, err := s.ByDay(ctx, from, to)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := json.Marshal(trips[0])
	if err != nil {
		t.Fatal(err)
	}
	want := `{"id":"t-1001","start":"2026-10-01T08:10:00+05:00","end":"2026-10-01T08:42:00+05:00","amount":2400,"payment":"card","commission":360}`
	if string(raw) != want {
		t.Errorf("stored trip =\n %s\nwant\n %s", raw, want)
	}
}

// Trips starting at the same instant are ordered by id, so the list is stable.
func TestByDayOrder(t *testing.T) {
	s := open(t, testdb.New(t), "")
	loc := almaty(t)
	ctx := context.Background()

	for _, tc := range []struct{ id, start string }{
		{"b", "2026-10-03T10:00:00+05:00"},
		{"c", "2026-10-03T09:00:00+05:00"},
		{"a", "2026-10-03T10:00:00+05:00"},
	} {
		tr := newTrip(t)
		tr.ID = tc.id
		tr.Start = mustTime(t, tc.start)
		tr.End = tr.Start.Add(10 * time.Minute)
		if _, _, err := s.Add(ctx, tr); err != nil {
			t.Fatal(err)
		}
	}
	from, to, _ := trip.DayBounds("2026-10-03", loc)
	trips, err := s.ByDay(ctx, from, to)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, tr := range trips {
		got = append(got, tr.ID)
	}
	if strings.Join(got, ",") != "c,a,b" {
		t.Errorf("order = %v, want [c a b]", got)
	}
}

// The day is computed twice: by trip.DayOf in Go and by AT TIME ZONE in SQL.
// They must agree, including around midnight and for trips sent in other
// offsets.
func TestDaysAgreesWithDayOf(t *testing.T) {
	s := open(t, testdb.New(t), seedFile)
	loc := almaty(t)
	ctx := context.Background()

	all := seedTrips(t)
	for i, start := range []string{
		"2026-10-06T18:59:59Z",      // 23:59:59 in Almaty, still Oct 6
		"2026-10-06T19:00:00Z",      // midnight in Almaty, already Oct 7
		"2026-10-07T23:30:00+03:00", // 01:30 on Oct 8 in Almaty
		"2026-10-10T01:00:00+09:00", // 21:00 on Oct 9 in Almaty
	} {
		tr := newTrip(t)
		tr.ID = "edge-" + string(rune('a'+i))
		tr.Start = mustTime(t, start)
		tr.End = tr.Start.Add(15 * time.Minute)
		if _, outcome, err := s.Add(ctx, tr); err != nil || outcome != trip.Created {
			t.Fatalf("Add %s = %v, %v", tr.ID, outcome, err)
		}
		all = append(all, tr)
	}

	want := map[string]int{}
	for _, tr := range all {
		want[trip.DayOf(tr, loc)]++
	}
	for _, day := range []string{"2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09"} {
		if want[day] != 1 {
			t.Fatalf("test data is off: %s has %d edge trips, want 1", day, want[day])
		}
	}

	days, err := s.Days(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(days) != len(want) {
		t.Errorf("Days returned %d days, want %d: %+v", len(days), len(want), days)
	}
	for i, d := range days {
		if d.TripsCount != want[d.Date] {
			t.Errorf("%s: SQL counts %d trips, DayOf counts %d", d.Date, d.TripsCount, want[d.Date])
		}
		if i > 0 && days[i-1].Date >= d.Date {
			t.Errorf("days are not ascending: %s before %s", days[i-1].Date, d.Date)
		}
		// And the per-day query must return the same trips the list promises.
		from, to, err := trip.DayBounds(d.Date, loc)
		if err != nil {
			t.Fatal(err)
		}
		trips, err := s.ByDay(ctx, from, to)
		if err != nil {
			t.Fatal(err)
		}
		if len(trips) != d.TripsCount {
			t.Errorf("%s: ByDay returns %d trips, Days says %d", d.Date, len(trips), d.TripsCount)
		}
	}
}

// The SQL must use the zone it is given, not the session's TimeZone setting.
func TestDaysIgnoresSessionTimeZone(t *testing.T) {
	dsn := testdb.New(t) + "&timezone=America/New_York"
	s := open(t, dsn, "")
	ctx := context.Background()

	tr := newTrip(t)
	tr.Start = mustTime(t, "2026-10-02T00:05:00+05:00") // Oct 1 in UTC and in New York
	tr.End = tr.Start.Add(20 * time.Minute)
	if _, _, err := s.Add(ctx, tr); err != nil {
		t.Fatal(err)
	}
	days, err := s.Days(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(days) != 1 || days[0].Date != "2026-10-02" {
		t.Errorf("Days = %+v, want one day 2026-10-02", days)
	}
}

func TestReopen(t *testing.T) {
	dsn := testdb.New(t)
	conn := rawConn(t, dsn)
	ctx := context.Background()
	seeded := len(seedTrips(t))
	tr := newTrip(t)

	first, err := store.Open(ctx, store.Config{DatabaseURL: dsn, Location: almaty(t), SeedFile: seedFile})
	if err != nil {
		t.Fatal(err)
	}
	if _, outcome, err := first.Add(ctx, tr); err != nil || outcome != trip.Created {
		t.Fatalf("Add = %v, %v; want Created", outcome, err)
	}
	first.Close()
	migrations := count(t, conn, "schema_migrations")
	if migrations == 0 {
		t.Fatal("no migrations recorded")
	}

	second := open(t, dsn, seedFile)
	if n := count(t, conn, "trips"); n != seeded+1 {
		t.Errorf("%d trips after reopening, want %d: seed applied twice or data lost", n, seeded+1)
	}
	if n := count(t, conn, "schema_migrations"); n != migrations {
		t.Errorf("%d migrations recorded after reopening, want %d", n, migrations)
	}
	if _, outcome, err := second.Add(ctx, tr); err != nil || outcome != trip.Duplicate {
		t.Errorf("Add after reopening = %v, %v; want Duplicate", outcome, err)
	}
}

// Several instances starting at once must migrate and seed exactly once.
func TestOpenConcurrently(t *testing.T) {
	dsn := testdb.New(t)
	loc := almaty(t)

	const instances = 5
	errs := make([]error, instances)
	var wg sync.WaitGroup
	for i := range instances {
		wg.Go(func() {
			s, err := store.Open(context.Background(), store.Config{
				DatabaseURL: dsn, Location: loc, SeedFile: seedFile, MaxConns: 2,
			})
			if err == nil {
				s.Close()
			}
			errs[i] = err
		})
	}
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			t.Errorf("instance %d: %v", i, err)
		}
	}
	conn := rawConn(t, dsn)
	if n, want := count(t, conn, "trips"), len(seedTrips(t)); n != want {
		t.Errorf("%d trips, want %d", n, want)
	}
}

func TestSeedRejectsBadFile(t *testing.T) {
	const valid = `{"id":"a","start":"2026-10-01T08:10:00+05:00","end":"2026-10-01T08:42:00+05:00","amount":2400,"payment":"card","commission":360}`
	tests := []struct {
		name, content, wantErr string
	}{
		{"invalid trip", `[` + valid + `,{"id":"b","start":"2026-10-01T09:00:00+05:00","end":"2026-10-01T09:30:00+05:00","amount":0,"payment":"cash","commission":0}]`, "is invalid"},
		{"repeated id", `[` + valid + `,` + valid + `]`, "repeats id"},
		{"unknown field", `[{"id":"a","start":"2026-10-01T08:10:00+05:00","end":"2026-10-01T08:42:00+05:00","amount":2400,"payment":"card","commission":360,"tip":5}]`, "unknown field"},
		{"not json", `oops`, "parse seed file"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dsn := testdb.New(t)
			path := filepath.Join(t.TempDir(), "trips.json")
			if err := os.WriteFile(path, []byte(tt.content), 0o600); err != nil {
				t.Fatal(err)
			}
			s, err := store.Open(context.Background(), store.Config{DatabaseURL: dsn, Location: almaty(t), SeedFile: path})
			if err == nil {
				s.Close()
				t.Fatal("Open succeeded, want an error")
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error = %v, want it to mention %q", err, tt.wantErr)
			}
			// Nothing from a rejected file may stay behind.
			if n := count(t, rawConn(t, dsn), "trips"); n != 0 {
				t.Errorf("%d trips left after a rejected seed, want 0", n)
			}
		})
	}

	t.Run("missing file", func(t *testing.T) {
		s, err := store.Open(context.Background(), store.Config{
			DatabaseURL: testdb.New(t), Location: almaty(t), SeedFile: filepath.Join(t.TempDir(), "nope.json"),
		})
		if err == nil {
			s.Close()
			t.Fatal("Open succeeded, want an error")
		}
	})
}

// The schema refuses rows that would not pass trip.Validate.
func TestCheckConstraints(t *testing.T) {
	dsn := testdb.New(t)
	open(t, dsn, "")
	conn := rawConn(t, dsn)
	ctx := context.Background()

	const insert = `INSERT INTO trips (id, start_at, end_at, amount, commission, payment) VALUES ($1, $2, $3, $4, $5, $6)`
	start := mustTime(t, "2026-10-01T08:10:00+05:00")
	end := start.Add(30 * time.Minute)

	tests := []struct {
		name       string
		args       []any
		constraint string
	}{
		{"zero amount", []any{"x", start, end, 0, 0, "cash"}, "trips_amount_positive"},
		{"negative amount", []any{"x", start, end, -5, 0, "cash"}, "trips_amount_positive"},
		{"end equals start", []any{"x", start, start, 100, 0, "cash"}, "trips_end_after_start"},
		{"end before start", []any{"x", end, start, 100, 0, "cash"}, "trips_end_after_start"},
		{"negative commission", []any{"x", start, end, 100, -1, "cash"}, "trips_commission_range"},
		{"commission above amount", []any{"x", start, end, 100, 101, "cash"}, "trips_commission_range"},
		{"unknown payment", []any{"x", start, end, 100, 0, "crypto"}, "trips_payment_known"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := conn.Exec(ctx, insert, tt.args...)
			if err == nil {
				t.Fatal("insert succeeded, want a constraint violation")
			}
			if !strings.Contains(err.Error(), tt.constraint) {
				t.Errorf("error = %v, want constraint %s", err, tt.constraint)
			}
		})
	}
	if _, err := conn.Exec(ctx, insert, "ok", start, end, 100, 100, "card"); err != nil {
		t.Errorf("valid row rejected: %v", err)
	}
	if n := count(t, conn, "trips"); n != 1 {
		t.Errorf("%d rows in trips, want 1", n)
	}
}

// Needs no database: nothing listens on the port.
func TestOpenGivesUpOnUnreachableDatabase(t *testing.T) {
	started := time.Now()
	s, err := store.Open(context.Background(), store.Config{
		DatabaseURL: "postgres://diary:diary@127.0.0.1:1/diary?sslmode=disable",
		Location:    time.UTC,
		ConnectWait: 2500 * time.Millisecond,
	})
	if err == nil {
		s.Close()
		t.Fatal("Open succeeded, want an error")
	}
	if !strings.Contains(err.Error(), "not reachable") {
		t.Errorf("error = %v, want it to say the database is not reachable", err)
	}
	if waited := time.Since(started); waited < time.Second || waited > 10*time.Second {
		t.Errorf("gave up after %s, want a couple of retries within the wait", waited)
	}
}
