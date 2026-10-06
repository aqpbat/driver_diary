package trip

// Totals are the money figures for a set of trips. Net is what the driver
// keeps: revenue minus commission.
type Totals struct {
	TripsCount int   `json:"trips_count"`
	Revenue    int64 `json:"revenue"`
	Commission int64 `json:"commission"`
	Net        int64 `json:"net"`
}

func (t *Totals) add(trip Trip) {
	t.TripsCount++
	t.Revenue += trip.Amount
	t.Commission += trip.Commission
	t.Net += trip.Amount - trip.Commission
}

// ByPayment splits totals by payment method. It is a struct rather than a map
// so both keys are always present in JSON, even when a method was not used.
type ByPayment struct {
	Cash Totals `json:"cash"`
	Card Totals `json:"card"`
}

// Summary is the overall totals plus the split by payment method.
type Summary struct {
	Totals
	ByPayment ByPayment `json:"by_payment"`
}

// Summarize adds up the given trips. It does not filter by day — pass the
// trips of one day. Trips are expected to be validated; a trip with an unknown
// payment method counts towards the overall totals only.
func Summarize(trips []Trip) Summary {
	var s Summary
	for _, t := range trips {
		s.add(t)
		switch t.Payment {
		case Cash:
			s.ByPayment.Cash.add(t)
		case Card:
			s.ByPayment.Card.add(t)
		}
	}
	return s
}
