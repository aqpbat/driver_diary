-- The CHECK constraints repeat the rules of trip.Validate: they are the last
-- line of defence if a row is ever written past the application.
CREATE TABLE trips (
    id         TEXT        PRIMARY KEY,
    start_at   TIMESTAMPTZ NOT NULL,
    end_at     TIMESTAMPTZ NOT NULL,
    amount     BIGINT      NOT NULL,
    commission BIGINT      NOT NULL,
    payment    TEXT        NOT NULL,
    CONSTRAINT trips_amount_positive  CHECK (amount > 0),
    CONSTRAINT trips_end_after_start  CHECK (end_at > start_at),
    CONSTRAINT trips_commission_range CHECK (commission BETWEEN 0 AND amount),
    CONSTRAINT trips_payment_known    CHECK (payment IN ('cash', 'card'))
);

CREATE INDEX trips_start_at_idx ON trips (start_at);
