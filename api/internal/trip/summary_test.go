package trip

import (
	"encoding/json"
	"os"
	"testing"
	"time"
)

// ride builds a trip where only the fields that matter to the summary vary.
func ride(amount, commission int64, p Payment) Trip {
	start := time.Date(2026, 10, 1, 8, 0, 0, 0, time.UTC)
	return Trip{ID: "x", Start: start, End: start.Add(20 * time.Minute), Amount: amount, Payment: p, Commission: commission}
}

func TestSummarize(t *testing.T) {
	tests := []struct {
		name  string
		trips []Trip
		want  Summary
	}{
		{
			name:  "empty day",
			trips: nil,
			want:  Summary{},
		},
		{
			name:  "cash only",
			trips: []Trip{ride(1500, 225, Cash), ride(900, 135, Cash)},
			want: Summary{
				Totals:    Totals{TripsCount: 2, Revenue: 2400, Commission: 360, Net: 2040},
				ByPayment: ByPayment{Cash: Totals{TripsCount: 2, Revenue: 2400, Commission: 360, Net: 2040}},
			},
		},
		{
			name:  "card only",
			trips: []Trip{ride(2400, 360, Card)},
			want: Summary{
				Totals:    Totals{TripsCount: 1, Revenue: 2400, Commission: 360, Net: 2040},
				ByPayment: ByPayment{Card: Totals{TripsCount: 1, Revenue: 2400, Commission: 360, Net: 2040}},
			},
		},
		{
			// The example from the API contract in PLAN.md.
			name:  "mixed day",
			trips: []Trip{ride(2400, 360, Card), ride(1500, 225, Cash)},
			want: Summary{
				Totals: Totals{TripsCount: 2, Revenue: 3900, Commission: 585, Net: 3315},
				ByPayment: ByPayment{
					Cash: Totals{TripsCount: 1, Revenue: 1500, Commission: 225, Net: 1275},
					Card: Totals{TripsCount: 1, Revenue: 2400, Commission: 360, Net: 2040},
				},
			},
		},
		{
			name:  "zero commission",
			trips: []Trip{ride(1000, 0, Cash), ride(2000, 0, Card)},
			want: Summary{
				Totals: Totals{TripsCount: 2, Revenue: 3000, Commission: 0, Net: 3000},
				ByPayment: ByPayment{
					Cash: Totals{TripsCount: 1, Revenue: 1000, Commission: 0, Net: 1000},
					Card: Totals{TripsCount: 1, Revenue: 2000, Commission: 0, Net: 2000},
				},
			},
		},
		{
			name:  "commission equal to amount leaves nothing",
			trips: []Trip{ride(700, 700, Cash)},
			want: Summary{
				Totals:    Totals{TripsCount: 1, Revenue: 700, Commission: 700, Net: 0},
				ByPayment: ByPayment{Cash: Totals{TripsCount: 1, Revenue: 700, Commission: 700, Net: 0}},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Summarize(tt.trips); got != tt.want {
				t.Errorf("Summarize =\n %+v\nwant\n %+v", got, tt.want)
			}
		})
	}
}

// An empty summary must still carry both payment keys, with zeros.
func TestSummaryJSONShape(t *testing.T) {
	got, err := json.Marshal(Summarize(nil))
	if err != nil {
		t.Fatal(err)
	}
	zero := `{"trips_count":0,"revenue":0,"commission":0,"net":0}`
	want := `{"trips_count":0,"revenue":0,"commission":0,"net":0,"by_payment":{"cash":` + zero + `,"card":` + zero + `}}`
	if string(got) != want {
		t.Errorf("JSON =\n %s\nwant\n %s", got, want)
	}
}

// The expected figures below were added up by hand from data/trips.json and
// must not be derived from the code under test.
func TestSummarizeSeedData(t *testing.T) {
	raw, err := os.ReadFile("../../data/trips.json")
	if err != nil {
		t.Fatal(err)
	}
	var trips []Trip
	if err := json.Unmarshal(raw, &trips); err != nil {
		t.Fatal(err)
	}

	almaty := mustLoc(t, "Asia/Almaty")
	byDay := map[string][]Trip{}
	seen := map[string]bool{}
	for _, tr := range trips {
		if errs := Validate(tr); errs != nil {
			t.Errorf("seed trip %q is invalid: %v", tr.ID, errs)
		}
		if seen[tr.ID] {
			t.Errorf("seed trip id %q is duplicated", tr.ID)
		}
		seen[tr.ID] = true
		day := DayOf(tr, almaty)
		byDay[day] = append(byDay[day], tr)
	}

	wantCounts := map[string]int{"2026-10-01": 6, "2026-10-02": 6, "2026-10-04": 4, "2026-10-05": 6}
	if len(byDay) != len(wantCounts) {
		t.Errorf("seed data covers %d days, want %d", len(byDay), len(wantCounts))
	}
	for day, want := range wantCounts {
		if got := len(byDay[day]); got != want {
			t.Errorf("%s: %d trips, want %d", day, got, want)
		}
	}

	wantSummaries := map[string]Summary{
		// Mixed day; its last trip starts at 23:55 and ends after midnight.
		"2026-10-01": {
			Totals: Totals{TripsCount: 6, Revenue: 12900, Commission: 1935, Net: 10965},
			ByPayment: ByPayment{
				Cash: Totals{TripsCount: 3, Revenue: 5200, Commission: 780, Net: 4420},
				Card: Totals{TripsCount: 3, Revenue: 7700, Commission: 1155, Net: 6545},
			},
		},
		// Cash only.
		"2026-10-04": {
			Totals:    Totals{TripsCount: 4, Revenue: 8800, Commission: 1320, Net: 7480},
			ByPayment: ByPayment{Cash: Totals{TripsCount: 4, Revenue: 8800, Commission: 1320, Net: 7480}},
		},
		// Has a zero-commission trip and a commission that is not exactly 15 %.
		"2026-10-05": {
			Totals: Totals{TripsCount: 6, Revenue: 13750, Commission: 1912, Net: 11838},
			ByPayment: ByPayment{
				Cash: Totals{TripsCount: 2, Revenue: 3750, Commission: 412, Net: 3338},
				Card: Totals{TripsCount: 4, Revenue: 10000, Commission: 1500, Net: 8500},
			},
		},
	}
	for day, want := range wantSummaries {
		if got := Summarize(byDay[day]); got != want {
			t.Errorf("%s: Summarize =\n %+v\nwant\n %+v", day, got, want)
		}
	}
}
