package httpapi_test

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
	_ "time/tzdata"

	"driverdiary/internal/httpapi"
	"driverdiary/internal/store"
	"driverdiary/internal/testdb"
	"driverdiary/internal/trip"
)

const seedFile = "../../data/trips.json"

var quiet = slog.New(slog.DiscardHandler)

func almaty(t *testing.T) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation("Asia/Almaty")
	if err != nil {
		t.Fatal(err)
	}
	return loc
}

// newAPI builds the API on top of a real store in a private schema.
func newAPI(t *testing.T, seed string) http.Handler {
	t.Helper()
	loc := almaty(t)
	s, err := store.Open(context.Background(), store.Config{
		DatabaseURL: testdb.New(t),
		Location:    loc,
		SeedFile:    seed,
		Logger:      quiet,
	})
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(s.Close)
	return httpapi.New(httpapi.Config{Store: s, Location: loc, Logger: quiet})
}

func do(h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	var req *http.Request
	if body == "" {
		req = httptest.NewRequest(method, path, nil)
	} else {
		req = httptest.NewRequest(method, path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

// wantJSON checks status, content type and that the body equals want once
// both are parsed, so key order and whitespace do not matter.
func wantJSON(t *testing.T, rec *httptest.ResponseRecorder, status int, want string) {
	t.Helper()
	if rec.Code != status {
		t.Errorf("status = %d, want %d; body: %s", rec.Code, status, rec.Body)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}
	var got, exp any
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("body is not JSON: %v; body: %s", err, rec.Body)
	}
	if err := json.Unmarshal([]byte(want), &exp); err != nil {
		t.Fatalf("bad expectation: %v", err)
	}
	gotNorm, _ := json.Marshal(got)
	expNorm, _ := json.Marshal(exp)
	if string(gotNorm) != string(expNorm) {
		t.Errorf("body =\n %s\nwant\n %s", gotNorm, expNorm)
	}
}

const (
	tripBody = `{"id":"7c1e0f5a","start":"2026-10-03T08:10:00+05:00","end":"2026-10-03T08:42:00+05:00","amount":2400,"payment":"card","commission":360}`
	// What the day of tripBody looks like while it is the only trip there.
	dayWithTrip = `{
		"date": "2026-10-03",
		"summary": {
			"trips_count": 1, "revenue": 2400, "commission": 360, "net": 2040,
			"by_payment": {
				"cash": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0},
				"card": {"trips_count": 1, "revenue": 2400, "commission": 360, "net": 2040}
			}
		},
		"trips": [` + tripBody + `]
	}`
)

func TestAddTripRepeatWritesNothing(t *testing.T) {
	h := newAPI(t, "")

	wantJSON(t, do(h, "POST", "/api/v1/trips", tripBody), http.StatusCreated, tripBody)
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-03", ""), http.StatusOK, dayWithTrip)

	// The client did not get the answer and sends the same request again.
	for range 3 {
		wantJSON(t, do(h, "POST", "/api/v1/trips", tripBody), http.StatusOK, tripBody)
	}
	// One trip, and the summary did not move.
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-03", ""), http.StatusOK, dayWithTrip)
	wantJSON(t, do(h, "GET", "/api/v1/days", ""), http.StatusOK, `{"days":[{"date":"2026-10-03","trips_count":1}]}`)
}

func TestAddTripSameIDOtherContentConflicts(t *testing.T) {
	h := newAPI(t, "")
	wantJSON(t, do(h, "POST", "/api/v1/trips", tripBody), http.StatusCreated, tripBody)

	changes := map[string]string{
		"amount":     strings.Replace(tripBody, `"amount":2400`, `"amount":2500`, 1),
		"commission": strings.Replace(tripBody, `"commission":360`, `"commission":0`, 1),
		"payment":    strings.Replace(tripBody, `"payment":"card"`, `"payment":"cash"`, 1),
		"start":      strings.Replace(tripBody, `T08:10:00`, `T08:11:00`, 1),
		"end":        strings.Replace(tripBody, `T08:42:00`, `T08:43:00`, 1),
		// The same wall clock in another offset is a different moment.
		"offset": strings.Replace(tripBody, `T08:10:00+05:00`, `T08:10:00+06:00`, 1),
	}
	for name, body := range changes {
		t.Run(name, func(t *testing.T) {
			if body == tripBody {
				t.Fatal("test body was not changed")
			}
			wantJSON(t, do(h, "POST", "/api/v1/trips", body), http.StatusConflict,
				`{"error":{"code":"id_conflict","message":"another trip with this id already exists"}}`)
		})
	}
	// The original trip is untouched.
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-03", ""), http.StatusOK, dayWithTrip)
}

func TestAddTripSameInstantOtherOffsetIsARepeat(t *testing.T) {
	h := newAPI(t, "")
	wantJSON(t, do(h, "POST", "/api/v1/trips", tripBody), http.StatusCreated, tripBody)

	// 08:10+05:00 is 03:10Z; 08:42+05:00 is 06:42+03:00.
	utc := strings.Replace(tripBody, `2026-10-03T08:10:00+05:00`, `2026-10-03T03:10:00Z`, 1)
	utc = strings.Replace(utc, `2026-10-03T08:42:00+05:00`, `2026-10-03T06:42:00+03:00`, 1)

	// Answered with the stored trip, rendered in the driver's zone.
	wantJSON(t, do(h, "POST", "/api/v1/trips", utc), http.StatusOK, tripBody)
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-03", ""), http.StatusOK, dayWithTrip)
}

func TestAddTripRace(t *testing.T) {
	h := newAPI(t, "")

	const clients = 50
	codes := make([]int, clients)
	start := make(chan struct{})
	var wg sync.WaitGroup
	for i := range clients {
		wg.Go(func() {
			<-start
			codes[i] = do(h, "POST", "/api/v1/trips", tripBody).Code
		})
	}
	close(start)
	wg.Wait()

	counts := map[int]int{}
	for _, c := range codes {
		counts[c]++
	}
	if counts[http.StatusCreated] != 1 || counts[http.StatusOK] != clients-1 {
		t.Errorf("status codes = %v, want one 201 and %d 200", counts, clients-1)
	}
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-03", ""), http.StatusOK, dayWithTrip)
}

// A trip sent in UTC lands on the day it started in the driver's zone and is
// returned in that zone.
func TestAddTripInAnotherOffsetLandsOnLocalDay(t *testing.T) {
	h := newAPI(t, "")

	// 20:30Z on Oct 1 is 01:30 on Oct 2 in Almaty.
	body := `{"id":"z","start":"2026-10-01T20:30:00Z","end":"2026-10-01T21:00:00Z","amount":1000,"payment":"cash","commission":150}`
	stored := `{"id":"z","start":"2026-10-02T01:30:00+05:00","end":"2026-10-02T02:00:00+05:00","amount":1000,"payment":"cash","commission":150}`

	wantJSON(t, do(h, "POST", "/api/v1/trips", body), http.StatusCreated, stored)
	wantJSON(t, do(h, "GET", "/api/v1/days", ""), http.StatusOK, `{"days":[{"date":"2026-10-02","trips_count":1}]}`)

	var day struct {
		Trips []json.RawMessage `json:"trips"`
	}
	for date, want := range map[string]int{"2026-10-01": 0, "2026-10-02": 1} {
		rec := do(h, "GET", "/api/v1/days/"+date, "")
		if err := json.Unmarshal(rec.Body.Bytes(), &day); err != nil {
			t.Fatal(err)
		}
		if len(day.Trips) != want {
			t.Errorf("%s has %d trips, want %d", date, len(day.Trips), want)
		}
	}
}

func TestReadRoutesOnSeedData(t *testing.T) {
	h := newAPI(t, seedFile)

	wantJSON(t, do(h, "GET", "/healthz", ""), http.StatusOK, `{"status":"ok"}`)

	wantJSON(t, do(h, "GET", "/api/v1/days", ""), http.StatusOK, `{"days":[
		{"date":"2026-10-01","trips_count":6},
		{"date":"2026-10-02","trips_count":6},
		{"date":"2026-10-04","trips_count":4},
		{"date":"2026-10-05","trips_count":6}
	]}`)

	// Cash only; figures added up by hand from data/trips.json.
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-04", ""), http.StatusOK, `{
		"date": "2026-10-04",
		"summary": {
			"trips_count": 4, "revenue": 8800, "commission": 1320, "net": 7480,
			"by_payment": {
				"cash": {"trips_count": 4, "revenue": 8800, "commission": 1320, "net": 7480},
				"card": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0}
			}
		},
		"trips": [
			{"id":"t-4001","start":"2026-10-04T09:00:00+05:00","end":"2026-10-04T09:25:00+05:00","amount":1400,"payment":"cash","commission":210},
			{"id":"t-4002","start":"2026-10-04T11:30:00+05:00","end":"2026-10-04T12:10:00+05:00","amount":2700,"payment":"cash","commission":405},
			{"id":"t-4003","start":"2026-10-04T14:15:00+05:00","end":"2026-10-04T14:40:00+05:00","amount":1600,"payment":"cash","commission":240},
			{"id":"t-4004","start":"2026-10-04T18:05:00+05:00","end":"2026-10-04T18:50:00+05:00","amount":3100,"payment":"cash","commission":465}
		]
	}`)

	// A day without trips is not an error: zeros and an empty list.
	wantJSON(t, do(h, "GET", "/api/v1/days/2026-10-03", ""), http.StatusOK, `{
		"date": "2026-10-03",
		"summary": {
			"trips_count": 0, "revenue": 0, "commission": 0, "net": 0,
			"by_payment": {
				"cash": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0},
				"card": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0}
			}
		},
		"trips": []
	}`)
}

// The trip at 23:55 that ends after midnight belongs to the day it started,
// and the trip at 00:05 to the next one.
func TestDayBoundariesOverHTTP(t *testing.T) {
	h := newAPI(t, seedFile)

	var day struct {
		Summary trip.Summary `json:"summary"`
		Trips   []trip.Trip  `json:"trips"`
	}
	get := func(date string) {
		t.Helper()
		rec := do(h, "GET", "/api/v1/days/"+date, "")
		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d", rec.Code)
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &day); err != nil {
			t.Fatal(err)
		}
	}

	get("2026-10-01")
	if last := day.Trips[len(day.Trips)-1]; last.ID != "t-1006" {
		t.Errorf("last trip of Oct 1 = %s, want t-1006 (starts 23:55)", last.ID)
	}
	want := trip.Summary{
		Totals: trip.Totals{TripsCount: 6, Revenue: 12900, Commission: 1935, Net: 10965},
		ByPayment: trip.ByPayment{
			Cash: trip.Totals{TripsCount: 3, Revenue: 5200, Commission: 780, Net: 4420},
			Card: trip.Totals{TripsCount: 3, Revenue: 7700, Commission: 1155, Net: 6545},
		},
	}
	if day.Summary != want {
		t.Errorf("summary of Oct 1 =\n %+v\nwant\n %+v", day.Summary, want)
	}

	get("2026-10-02")
	if first := day.Trips[0]; first.ID != "t-2001" {
		t.Errorf("first trip of Oct 2 = %s, want t-2001 (starts 00:05)", first.ID)
	}
}

func TestBadDate(t *testing.T) {
	h := newAPI(t, "")
	for _, date := range []string{"yesterday", "2026-10-1", "2026-13-01", "2026-02-30", "01.10.2026", "2026-10-01T00:00:00Z"} {
		t.Run(date, func(t *testing.T) {
			wantJSON(t, do(h, "GET", "/api/v1/days/"+date, ""), http.StatusBadRequest,
				`{"error":{"code":"invalid_date","message":"date must look like 2026-10-01"}}`)
		})
	}
}

func TestAddTripRejectsBadBodies(t *testing.T) {
	h := newAPI(t, "")

	const invalidJSON = `{"error":{"code":"invalid_json","message":"request body must be a single JSON object"}}`
	validation := func(fields string) string {
		return `{"error":{"code":"validation_failed","message":"trip is invalid","fields":` + fields + `}}`
	}
	const badTime = "must be RFC 3339 with an offset, like 2026-10-01T08:10:00+05:00"

	tests := []struct {
		name   string
		body   string
		status int
		want   string
	}{
		{"not json", `hello`, 400, invalidJSON},
		{"empty body", ``, 400, invalidJSON},
		{"cut off", `{"id":"a","start":`, 400, invalidJSON},
		{"array", `[` + tripBody + `]`, 400, invalidJSON},
		{"string", `"trip"`, 400, invalidJSON},
		{"two objects", tripBody + tripBody, 400, invalidJSON},
		{"trailing garbage", tripBody + ` oops`, 400, invalidJSON},

		{"unknown field", strings.Replace(tripBody, `{`, `{"tip":100,`, 1), 422,
			validation(`{"tip":"unknown field"}`)},
		{"empty object", `{}`, 422, validation(`{
			"id":"is required","start":"is required","end":"is required",
			"amount":"must be greater than 0","payment":"must be one of: cash, card"}`)},
		{"several errors at once", `{"id":"","start":"2026-10-03T08:10:00+05:00","end":"2026-10-03T08:10:00+05:00","amount":0,"payment":"bonus","commission":-5}`, 422,
			validation(`{
			"id":"is required","end":"must be after start","amount":"must be greater than 0",
			"commission":"must not be negative","payment":"must be one of: cash, card"}`)},
		{"end before start", strings.Replace(tripBody, `T08:42:00`, `T08:00:00`, 1), 422,
			validation(`{"end":"must be after start"}`)},
		{"negative amount", strings.Replace(tripBody, `"amount":2400`, `"amount":-1`, 1), 422,
			validation(`{"amount":"must be greater than 0"}`)},
		{"commission above amount", strings.Replace(tripBody, `"commission":360`, `"commission":2401`, 1), 422,
			validation(`{"commission":"must not exceed amount"}`)},
		{"unknown payment", strings.Replace(tripBody, `"card"`, `"crypto"`, 1), 422,
			validation(`{"payment":"must be one of: cash, card"}`)},

		{"fractional amount", strings.Replace(tripBody, `"amount":2400`, `"amount":2400.5`, 1), 422,
			validation(`{"amount":"must be an integer"}`)},
		{"amount as a string", strings.Replace(tripBody, `"amount":2400`, `"amount":"2400"`, 1), 422,
			validation(`{"amount":"must be an integer"}`)},
		{"amount too big for int64", strings.Replace(tripBody, `"amount":2400`, `"amount":99999999999999999999`, 1), 422,
			validation(`{"amount":"must be an integer"}`)},
		{"id as a number", strings.Replace(tripBody, `"id":"7c1e0f5a"`, `"id":7`, 1), 422,
			validation(`{"id":"must be a string"}`)},
		{"time without offset", strings.Replace(tripBody, `T08:10:00+05:00`, `T08:10:00`, 1), 422,
			validation(`{"start":"` + badTime + `"}`)},
		{"time in another format", strings.Replace(tripBody, `2026-10-03T08:42:00+05:00`, `03.10.2026 08:42`, 1), 422,
			validation(`{"end":"` + badTime + `"}`)},
		{"wrong type and other errors together", `{"id":"a","start":"nope","end":"2026-10-03T08:42:00+05:00","amount":"x","payment":"cash","commission":0}`, 422,
			validation(`{"start":"` + badTime + `","amount":"must be an integer"}`)},

		{"too large", `{"id":"` + strings.Repeat("x", 70<<10) + `"}`, 413,
			`{"error":{"code":"body_too_large","message":"request body must be at most 64 KB"}}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			wantJSON(t, do(h, "POST", "/api/v1/trips", tt.body), tt.status, tt.want)
		})
	}

	// None of the above may have written anything.
	wantJSON(t, do(h, "GET", "/api/v1/days", ""), http.StatusOK, `{"days":[]}`)
}

// failingStore stands in for a database that is down. It is used only for
// the error paths; everything else runs against PostgreSQL.
type failingStore struct{}

var errDown = errors.New(`pq: relation "trips" does not exist (SQLSTATE 42P01)`)

func (failingStore) Ping(context.Context) error                    { return errDown }
func (failingStore) Days(context.Context) ([]trip.DayCount, error) { return nil, errDown }
func (failingStore) ByDay(context.Context, time.Time, time.Time) ([]trip.Trip, error) {
	return nil, errDown
}
func (failingStore) Add(context.Context, trip.Trip) (trip.Trip, trip.AddOutcome, error) {
	return trip.Trip{}, 0, errDown
}

func TestStoreFailure(t *testing.T) {
	h := httpapi.New(httpapi.Config{Store: failingStore{}, Location: almaty(t), Logger: quiet})

	const internal = `{"error":{"code":"internal","message":"internal error"}}`
	for _, tc := range []struct{ method, path, body string }{
		{"GET", "/api/v1/days", ""},
		{"GET", "/api/v1/days/2026-10-01", ""},
		{"POST", "/api/v1/trips", tripBody},
	} {
		rec := do(h, tc.method, tc.path, tc.body)
		wantJSON(t, rec, http.StatusInternalServerError, internal)
		if strings.Contains(rec.Body.String(), "SQLSTATE") {
			t.Errorf("%s %s leaks the database error: %s", tc.method, tc.path, rec.Body)
		}
	}

	wantJSON(t, do(h, "GET", "/healthz", ""), http.StatusServiceUnavailable,
		`{"error":{"code":"database_unavailable","message":"database is not reachable"}}`)
}

func TestUnknownRoutesAndMethods(t *testing.T) {
	h := httpapi.New(httpapi.Config{Store: failingStore{}, Location: almaty(t), Logger: quiet})

	const notFound = `{"error":{"code":"not_found","message":"no such route"}}`
	for _, path := range []string{"/", "/api/v1", "/api/v1/trips/7", "/api/v2/days", "/api/v1/days/2026-10-01/trips"} {
		wantJSON(t, do(h, "GET", path, ""), http.StatusNotFound, notFound)
	}

	for _, tc := range []struct{ method, path, allow string }{
		{"POST", "/api/v1/days", "GET"},
		{"DELETE", "/api/v1/days/2026-10-01", "GET"},
		{"GET", "/api/v1/trips", "POST"},
		{"PUT", "/api/v1/trips", "POST"},
		{"POST", "/healthz", "GET"},
	} {
		rec := do(h, tc.method, tc.path, "")
		wantJSON(t, rec, http.StatusMethodNotAllowed,
			`{"error":{"code":"method_not_allowed","message":"use `+tc.allow+`"}}`)
		if got := rec.Header().Get("Allow"); got != tc.allow {
			t.Errorf("%s %s: Allow = %q, want %q", tc.method, tc.path, got, tc.allow)
		}
	}
}

func TestCORS(t *testing.T) {
	newHandler := func(origins ...string) http.Handler {
		return httpapi.New(httpapi.Config{Store: failingStore{}, Location: almaty(t), AllowedOrigins: origins, Logger: quiet})
	}
	request := func(h http.Handler, method, origin string, preflight bool) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, "/api/v1/trips", nil)
		if origin != "" {
			req.Header.Set("Origin", origin)
		}
		if preflight {
			req.Header.Set("Access-Control-Request-Method", "POST")
			req.Header.Set("Access-Control-Request-Headers", "content-type")
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}
	const demo = "https://demo.example"

	t.Run("any origin", func(t *testing.T) {
		h := newHandler("*")
		rec := request(h, "OPTIONS", demo, true)
		if rec.Code != http.StatusNoContent {
			t.Errorf("preflight status = %d, want 204", rec.Code)
		}
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "*" {
			t.Errorf("Allow-Origin = %q, want *", got)
		}
		if got := rec.Header().Get("Access-Control-Allow-Methods"); !strings.Contains(got, "POST") {
			t.Errorf("Allow-Methods = %q, want it to include POST", got)
		}
		if got := rec.Header().Get("Access-Control-Allow-Headers"); got != "Content-Type" {
			t.Errorf("Allow-Headers = %q, want Content-Type", got)
		}
		// Errors carry the header too, or the browser hides them from the app.
		rec = request(h, "POST", demo, false)
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "*" {
			t.Errorf("Allow-Origin on an error response = %q, want *", got)
		}
	})

	t.Run("listed origin", func(t *testing.T) {
		h := newHandler(demo, "http://localhost:5000")
		rec := request(h, "OPTIONS", demo, true)
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != demo {
			t.Errorf("Allow-Origin = %q, want %q", got, demo)
		}
		if got := rec.Header().Get("Vary"); got != "Origin" {
			t.Errorf("Vary = %q, want Origin", got)
		}
	})

	t.Run("other origin", func(t *testing.T) {
		h := newHandler(demo)
		for _, preflight := range []bool{true, false} {
			rec := request(h, map[bool]string{true: "OPTIONS", false: "POST"}[preflight], "https://evil.example", preflight)
			if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
				t.Errorf("Allow-Origin = %q, want none", got)
			}
		}
	})

	t.Run("turned off", func(t *testing.T) {
		rec := request(newHandler(), "OPTIONS", demo, true)
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
			t.Errorf("Allow-Origin = %q, want none", got)
		}
		if rec.Code != http.StatusMethodNotAllowed {
			t.Errorf("status = %d, want 405", rec.Code)
		}
	})
}
