package trip

import (
	"strings"
	"testing"
	"time"
	_ "time/tzdata"
)

func mustLoc(t *testing.T, name string) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation(name)
	if err != nil {
		t.Fatalf("load location %s: %v", name, err)
	}
	return loc
}

func mustTime(t *testing.T, s string) time.Time {
	t.Helper()
	v, err := time.Parse(time.RFC3339, s)
	if err != nil {
		t.Fatalf("parse time %q: %v", s, err)
	}
	return v
}

func TestParsePayment(t *testing.T) {
	for _, s := range []string{"cash", "card"} {
		p, err := ParsePayment(s)
		if err != nil || string(p) != s {
			t.Errorf("ParsePayment(%q) = %q, %v; want %q, nil", s, p, err, s)
		}
	}
	for _, s := range []string{"", "Cash", "CARD", "crypto", " cash"} {
		if p, err := ParsePayment(s); err == nil {
			t.Errorf("ParsePayment(%q) = %q, nil; want error", s, p)
		}
	}
}

func TestDayOf(t *testing.T) {
	almaty := mustLoc(t, "Asia/Almaty")

	tests := []struct {
		name  string
		start string
		end   string
		want  string
	}{
		{"midday", "2026-10-01T12:00:00+05:00", "2026-10-01T12:30:00+05:00", "2026-10-01"},
		{"23:55 stays on its day", "2026-10-01T23:55:00+05:00", "2026-10-01T23:59:00+05:00", "2026-10-01"},
		{"00:05 is the new day", "2026-10-02T00:05:00+05:00", "2026-10-02T00:30:00+05:00", "2026-10-02"},
		{"exact midnight is the new day", "2026-10-02T00:00:00+05:00", "2026-10-02T00:10:00+05:00", "2026-10-02"},
		{"crossing midnight counts by start", "2026-10-01T23:50:00+05:00", "2026-10-02T00:20:00+05:00", "2026-10-01"},
		// 20:30Z on Oct 1 is 01:30 on Oct 2 in Almaty.
		{"sent in UTC, next day locally", "2026-10-01T20:30:00Z", "2026-10-01T21:00:00Z", "2026-10-02"},
		// 18:59:59Z is 23:59:59 in Almaty, 19:00Z is already midnight.
		{"sent in UTC, last second of the day", "2026-10-01T18:59:59Z", "2026-10-01T19:30:00Z", "2026-10-01"},
		{"sent in UTC, first second of the day", "2026-10-01T19:00:00Z", "2026-10-01T19:30:00Z", "2026-10-02"},
		// 23:30+03:00 on Oct 1 is 01:30 on Oct 2 in Almaty.
		{"sent in +03:00, next day locally", "2026-10-01T23:30:00+03:00", "2026-10-01T23:50:00+03:00", "2026-10-02"},
		// 01:00+09:00 on Oct 2 is 21:00 on Oct 1 in Almaty.
		{"sent in +09:00, previous day locally", "2026-10-02T01:00:00+09:00", "2026-10-02T01:20:00+09:00", "2026-10-01"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			trip := Trip{Start: mustTime(t, tt.start), End: mustTime(t, tt.end)}
			if got := DayOf(trip, almaty); got != tt.want {
				t.Errorf("DayOf = %s, want %s", got, tt.want)
			}
		})
	}
}

func TestDayOfDependsOnLocation(t *testing.T) {
	trip := Trip{Start: mustTime(t, "2026-10-01T20:30:00Z")}

	if got := DayOf(trip, time.UTC); got != "2026-10-01" {
		t.Errorf("DayOf in UTC = %s, want 2026-10-01", got)
	}
	if got := DayOf(trip, mustLoc(t, "Asia/Almaty")); got != "2026-10-02" {
		t.Errorf("DayOf in Almaty = %s, want 2026-10-02", got)
	}
}

func TestDayBounds(t *testing.T) {
	almaty := mustLoc(t, "Asia/Almaty")

	from, to, err := DayBounds("2026-10-01", almaty)
	if err != nil {
		t.Fatal(err)
	}
	if want := mustTime(t, "2026-10-01T00:00:00+05:00"); !from.Equal(want) {
		t.Errorf("from = %s, want %s", from, want)
	}
	if want := mustTime(t, "2026-10-02T00:00:00+05:00"); !to.Equal(want) {
		t.Errorf("to = %s, want %s", to, want)
	}

	// Every trip start must fall inside the bounds of its own day.
	for _, start := range []string{"2026-10-01T23:55:00+05:00", "2026-10-02T00:05:00+05:00", "2026-10-01T19:00:00Z"} {
		tr := Trip{Start: mustTime(t, start)}
		from, to, err := DayBounds(DayOf(tr, almaty), almaty)
		if err != nil {
			t.Fatal(err)
		}
		if tr.Start.Before(from) || !tr.Start.Before(to) {
			t.Errorf("start %s is outside [%s, %s)", start, from, to)
		}
	}

	for _, bad := range []string{"", "2026-10-1", "2026-13-01", "2026-02-30", "01.10.2026", "2026-10-01T00:00:00Z", "today"} {
		if _, _, err := DayBounds(bad, almaty); err == nil {
			t.Errorf("DayBounds(%q): want error", bad)
		}
	}
}

func TestEqual(t *testing.T) {
	base := Trip{
		ID:         "a",
		Start:      mustTime(t, "2026-10-01T08:10:00+05:00"),
		End:        mustTime(t, "2026-10-01T08:42:00+05:00"),
		Amount:     2400,
		Payment:    Card,
		Commission: 360,
	}
	with := func(change func(*Trip)) Trip {
		c := base
		change(&c)
		return c
	}

	tests := []struct {
		name  string
		other Trip
		want  bool
	}{
		{"identical", base, true},
		{"same instants in another offset", with(func(c *Trip) {
			c.Start = mustTime(t, "2026-10-01T03:10:00Z")
			c.End = mustTime(t, "2026-10-01T06:42:00+03:00")
		}), true},
		{"different id", with(func(c *Trip) { c.ID = "b" }), false},
		{"different start", with(func(c *Trip) { c.Start = c.Start.Add(time.Second) }), false},
		{"different end", with(func(c *Trip) { c.End = c.End.Add(time.Minute) }), false},
		// Same wall clock, different offset: a different instant.
		{"same wall clock in another offset", with(func(c *Trip) {
			c.Start = mustTime(t, "2026-10-01T08:10:00Z")
		}), false},
		{"different amount", with(func(c *Trip) { c.Amount = 2500 }), false},
		{"different payment", with(func(c *Trip) { c.Payment = Cash }), false},
		{"different commission", with(func(c *Trip) { c.Commission = 0 }), false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Equal(base, tt.other); got != tt.want {
				t.Errorf("Equal = %v, want %v", got, tt.want)
			}
			if got := Equal(tt.other, base); got != tt.want {
				t.Errorf("Equal (swapped) = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestValidate(t *testing.T) {
	valid := Trip{
		ID:         "a",
		Start:      mustTime(t, "2026-10-01T08:10:00+05:00"),
		End:        mustTime(t, "2026-10-01T08:42:00+05:00"),
		Amount:     2400,
		Payment:    Card,
		Commission: 360,
	}
	with := func(change func(*Trip)) Trip {
		c := valid
		change(&c)
		return c
	}

	tests := []struct {
		name string
		trip Trip
		want FieldErrors
	}{
		{"valid", valid, nil},
		{"zero commission is allowed", with(func(c *Trip) { c.Commission = 0 }), nil},
		{"commission equal to amount is allowed", with(func(c *Trip) { c.Commission = c.Amount }), nil},
		{"id of 64 characters is allowed", with(func(c *Trip) { c.ID = strings.Repeat("я", 64) }), nil},
		{"end in another offset but later is allowed", with(func(c *Trip) {
			c.End = mustTime(t, "2026-10-01T03:11:00Z")
		}), nil},

		{"empty id", with(func(c *Trip) { c.ID = "" }),
			FieldErrors{"id": "is required"}},
		{"blank id", with(func(c *Trip) { c.ID = "  \t" }),
			FieldErrors{"id": "is required"}},
		{"id too long", with(func(c *Trip) { c.ID = strings.Repeat("x", 65) }),
			FieldErrors{"id": "must be at most 64 characters"}},
		{"id with a NUL byte", with(func(c *Trip) { c.ID = "a\x00b" }),
			FieldErrors{"id": "must not contain control characters"}},

		{"missing start", with(func(c *Trip) { c.Start = time.Time{} }),
			FieldErrors{"start": "is required"}},
		{"missing end", with(func(c *Trip) { c.End = time.Time{} }),
			FieldErrors{"end": "is required"}},
		{"end equals start", with(func(c *Trip) { c.End = c.Start }),
			FieldErrors{"end": "must be after start"}},
		{"end before start", with(func(c *Trip) { c.End = c.Start.Add(-time.Minute) }),
			FieldErrors{"end": "must be after start"}},
		// Later on the wall clock, but the same instant as start.
		{"end equals start in another offset", with(func(c *Trip) {
			c.End = mustTime(t, "2026-10-01T09:10:00+06:00")
		}), FieldErrors{"end": "must be after start"}},

		{"zero amount", with(func(c *Trip) { c.Amount = 0; c.Commission = 0 }),
			FieldErrors{"amount": "must be greater than 0"}},
		{"negative amount", with(func(c *Trip) { c.Amount = -100; c.Commission = 0 }),
			FieldErrors{"amount": "must be greater than 0"}},
		{"negative commission", with(func(c *Trip) { c.Commission = -1 }),
			FieldErrors{"commission": "must not be negative"}},
		{"commission above amount", with(func(c *Trip) { c.Commission = c.Amount + 1 }),
			FieldErrors{"commission": "must not exceed amount"}},

		{"unknown payment", with(func(c *Trip) { c.Payment = "crypto" }),
			FieldErrors{"payment": "must be one of: cash, card"}},
		{"empty payment", with(func(c *Trip) { c.Payment = "" }),
			FieldErrors{"payment": "must be one of: cash, card"}},

		{"several errors at once", with(func(c *Trip) {
			c.ID = ""
			c.End = c.Start
			c.Amount = 0
			c.Commission = -5
			c.Payment = "bonus"
		}), FieldErrors{
			"id":         "is required",
			"end":        "must be after start",
			"amount":     "must be greater than 0",
			"commission": "must not be negative",
			"payment":    "must be one of: cash, card",
		}},
		{"zero value trip", Trip{}, FieldErrors{
			"id":      "is required",
			"start":   "is required",
			"end":     "is required",
			"amount":  "must be greater than 0",
			"payment": "must be one of: cash, card",
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Validate(tt.trip)
			if tt.want == nil {
				if got != nil {
					t.Fatalf("Validate = %v, want nil", got)
				}
				return
			}
			if len(got) != len(tt.want) {
				t.Errorf("Validate = %v, want %v", got, tt.want)
			}
			for field, msg := range tt.want {
				if got[field] != msg {
					t.Errorf("field %q: got %q, want %q", field, got[field], msg)
				}
			}
		})
	}
}
