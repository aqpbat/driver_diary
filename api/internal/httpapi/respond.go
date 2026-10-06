package httpapi

import (
	"encoding/json"
	"net/http"

	"driverdiary/internal/trip"
)

// apiError is an error as the client sees it.
type apiError struct {
	Status  int              `json:"-"`
	Code    string           `json:"code"`
	Message string           `json:"message"`
	Fields  trip.FieldErrors `json:"fields,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	raw, err := json.Marshal(body)
	if err != nil {
		// Only possible with a programming mistake in a response type.
		status = http.StatusInternalServerError
		raw = []byte(`{"error":{"code":"internal","message":"internal error"}}`)
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_, _ = w.Write(append(raw, '\n'))
}

func writeError(w http.ResponseWriter, e apiError) {
	writeJSON(w, e.Status, map[string]apiError{"error": e})
}

// internalError logs the real cause and tells the client nothing about it:
// the text of a database error must not leak into a response.
func (a *api) internalError(w http.ResponseWriter, r *http.Request, err error) {
	a.log.Error("request failed", "method", r.Method, "path", r.URL.Path, "error", err)
	writeError(w, apiError{Status: http.StatusInternalServerError, Code: "internal", Message: "internal error"})
}

func notFound(w http.ResponseWriter, _ *http.Request) {
	writeError(w, apiError{Status: http.StatusNotFound, Code: "not_found", Message: "no such route"})
}

func methodNotAllowed(allowed string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Allow", allowed)
		writeError(w, apiError{Status: http.StatusMethodNotAllowed, Code: "method_not_allowed", Message: "use " + allowed})
	}
}
