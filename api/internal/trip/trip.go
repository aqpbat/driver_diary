// Package trip holds the trip model and the rules around it: validation,
// which day a trip belongs to, the per-day summary and duplicate detection.
// It is pure: no HTTP, no I/O, no clock.
package trip

import (
	"fmt"
	"time"
)

// Payment is how the passenger paid for a trip.
type Payment string

const (
	Cash Payment = "cash"
	Card Payment = "card"
)

// ParsePayment converts a raw string into a Payment, rejecting unknown values.
func ParsePayment(s string) (Payment, error) {
	p := Payment(s)
	if !p.Valid() {
		return "", fmt.Errorf("unknown payment %q", s)
	}
	return p, nil
}

// Valid reports whether p is one of the known payment methods.
func (p Payment) Valid() bool {
	return p == Cash || p == Card
}

// Trip is a single ride. Money is whole tenge.
type Trip struct {
	ID         string    `json:"id"`
	Start      time.Time `json:"start"`
	End        time.Time `json:"end"`
	Amount     int64     `json:"amount"`
	Payment    Payment   `json:"payment"`
	Commission int64     `json:"commission"`
}

// dayLayout is the date format used for days across the API.
const dayLayout = "2006-01-02"

// DayOf returns the day a trip belongs to: the local date of its start in loc.
// The offset the trip was sent with does not matter, and neither does its end,
// so a trip that crosses midnight stays on the day it started.
func DayOf(t Trip, loc *time.Location) string {
	return t.Start.In(loc).Format(dayLayout)
}

// Equal reports whether a and b describe the same trip. Times are compared as
// instants, so 08:10+05:00 and 03:10Z are equal.
func Equal(a, b Trip) bool {
	return a.ID == b.ID &&
		a.Start.Equal(b.Start) &&
		a.End.Equal(b.End) &&
		a.Amount == b.Amount &&
		a.Payment == b.Payment &&
		a.Commission == b.Commission
}
