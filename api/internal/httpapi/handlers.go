package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"driverdiary/internal/trip"
)

const (
	maxBodyBytes  = 64 << 10
	healthTimeout = time.Second
)

func (a *api) health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), healthTimeout)
	defer cancel()
	if err := a.store.Ping(ctx); err != nil {
		a.log.Warn("health check failed", "error", err)
		writeError(w, apiError{Status: http.StatusServiceUnavailable, Code: "database_unavailable", Message: "database is not reachable"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

type daysResponse struct {
	Days []trip.DayCount `json:"days"`
}

func (a *api) listDays(w http.ResponseWriter, r *http.Request) {
	days, err := a.store.Days(r.Context())
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if days == nil {
		days = []trip.DayCount{} // "days": [] rather than null
	}
	writeJSON(w, http.StatusOK, daysResponse{Days: days})
}

type dayResponse struct {
	Date    string       `json:"date"`
	Summary trip.Summary `json:"summary"`
	Trips   []trip.Trip  `json:"trips"`
}

func (a *api) getDay(w http.ResponseWriter, r *http.Request) {
	date := r.PathValue("date")
	from, to, err := trip.DayBounds(date, a.loc)
	if err != nil {
		writeError(w, apiError{Status: http.StatusBadRequest, Code: "invalid_date", Message: "date must look like 2026-10-01"})
		return
	}
	trips, err := a.store.ByDay(r.Context(), from, to)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	if trips == nil {
		trips = []trip.Trip{}
	}
	writeJSON(w, http.StatusOK, dayResponse{Date: date, Summary: trip.Summarize(trips), Trips: trips})
}

func (a *api) addTrip(w http.ResponseWriter, r *http.Request) {
	t, apiErr := decodeTrip(w, r)
	if apiErr != nil {
		writeError(w, *apiErr)
		return
	}
	saved, outcome, err := a.store.Add(r.Context(), t)
	if err != nil {
		a.internalError(w, r, err)
		return
	}
	switch outcome {
	case trip.Created:
		writeJSON(w, http.StatusCreated, saved)
	case trip.Duplicate:
		writeJSON(w, http.StatusOK, saved)
	case trip.Conflict:
		writeError(w, apiError{Status: http.StatusConflict, Code: "id_conflict", Message: "another trip with this id already exists"})
	default:
		a.internalError(w, r, errors.New("store returned an unknown outcome"))
	}
}

// tripInput mirrors the request body with times still as text, so that a
// badly formatted time is reported against its field instead of failing the
// whole body as "not JSON".
type tripInput struct {
	ID         string `json:"id"`
	Start      string `json:"start"`
	End        string `json:"end"`
	Amount     int64  `json:"amount"`
	Payment    string `json:"payment"`
	Commission int64  `json:"commission"`
}

const (
	msgBadTime    = "must be RFC 3339 with an offset, like 2026-10-01T08:10:00+05:00"
	msgBadInteger = "must be an integer"
	msgBadString  = "must be a string"
)

// decodeTrip reads and checks the body of POST /trips. It reports every
// invalid field at once.
func decodeTrip(w http.ResponseWriter, r *http.Request) (trip.Trip, *apiError) {
	invalidJSON := &apiError{Status: http.StatusBadRequest, Code: "invalid_json", Message: "request body must be a single JSON object"}

	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	dec.DisallowUnknownFields()

	var in tripInput
	// Problems found here win over what trip.Validate says about the same
	// field: "must be an integer" is more useful than "must be greater than 0".
	fields := trip.FieldErrors{}

	if err := dec.Decode(&in); err != nil {
		var tooLarge *http.MaxBytesError
		var wrongType *json.UnmarshalTypeError
		switch {
		case errors.As(err, &tooLarge):
			return trip.Trip{}, &apiError{Status: http.StatusRequestEntityTooLarge, Code: "body_too_large", Message: "request body must be at most 64 KB"}
		case errors.As(err, &wrongType) && wrongType.Field != "":
			// The decoder skips the offending field and fills in the rest.
			if wrongType.Field == "amount" || wrongType.Field == "commission" {
				fields[wrongType.Field] = msgBadInteger
			} else {
				fields[wrongType.Field] = msgBadString
			}
		case strings.HasPrefix(err.Error(), "json: unknown field "):
			// encoding/json has no typed error for this one.
			name := strings.Trim(strings.TrimPrefix(err.Error(), "json: unknown field "), `"`)
			fields[name] = "unknown field"
		default:
			return trip.Trip{}, invalidJSON
		}
	}
	if _, err := dec.Token(); err != io.EOF {
		return trip.Trip{}, invalidJSON
	}

	t := trip.Trip{
		ID:         in.ID,
		Start:      parseTime("start", in.Start, fields),
		End:        parseTime("end", in.End, fields),
		Amount:     in.Amount,
		Payment:    trip.Payment(in.Payment),
		Commission: in.Commission,
	}
	errs := trip.Validate(t)
	if len(fields) > 0 {
		if errs == nil {
			errs = trip.FieldErrors{}
		}
		for name, msg := range fields {
			errs[name] = msg
		}
	}
	if errs != nil {
		return trip.Trip{}, &apiError{Status: http.StatusUnprocessableEntity, Code: "validation_failed", Message: "trip is invalid", Fields: errs}
	}
	return t, nil
}

// parseTime returns the zero time for an empty or malformed value. A missing
// value is left for trip.Validate to report as required.
func parseTime(field, value string, fields trip.FieldErrors) time.Time {
	if value == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339, value)
	if err != nil {
		if _, reported := fields[field]; !reported {
			fields[field] = msgBadTime
		}
		return time.Time{}
	}
	return t
}
