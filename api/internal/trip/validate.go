package trip

import (
	"strings"
	"unicode/utf8"
)

// MaxIDLength is the longest accepted trip id, in characters.
const MaxIDLength = 64

// FieldErrors maps a JSON field name to what is wrong with it.
type FieldErrors map[string]string

// Validate checks every field of t and returns all problems at once, keyed by
// JSON field name. It returns nil when the trip is valid.
func Validate(t Trip) FieldErrors {
	errs := FieldErrors{}

	switch {
	case strings.TrimSpace(t.ID) == "":
		errs["id"] = "is required"
	case utf8.RuneCountInString(t.ID) > MaxIDLength:
		errs["id"] = "must be at most 64 characters"
	}

	if t.Start.IsZero() {
		errs["start"] = "is required"
	}
	switch {
	case t.End.IsZero():
		errs["end"] = "is required"
	case !t.Start.IsZero() && !t.End.After(t.Start):
		errs["end"] = "must be after start"
	}

	if t.Amount <= 0 {
		errs["amount"] = "must be greater than 0"
	}
	switch {
	case t.Commission < 0:
		errs["commission"] = "must not be negative"
	case t.Amount > 0 && t.Commission > t.Amount:
		// Only meaningful against a valid amount; otherwise the amount error
		// already tells the client what to fix.
		errs["commission"] = "must not exceed amount"
	}

	if !t.Payment.Valid() {
		errs["payment"] = "must be one of: cash, card"
	}

	if len(errs) == 0 {
		return nil
	}
	return errs
}
