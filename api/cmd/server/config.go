package main

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

type config struct {
	Port           string
	Location       *time.Location
	TripsFile      string
	DatabaseURL    string
	AllowedOrigins []string
}

// loadConfig reads the configuration from the environment. getenv is a
// parameter so tests do not have to touch the real environment.
func loadConfig(getenv func(string) string) (config, error) {
	cfg := config{
		Port:        orDefault(getenv("PORT"), "8080"),
		TripsFile:   orDefault(getenv("TRIPS_FILE"), "data/trips.json"),
		DatabaseURL: getenv("DATABASE_URL"),
	}

	if n, err := strconv.Atoi(cfg.Port); err != nil || n < 1 || n > 65535 {
		return config{}, fmt.Errorf("PORT %q is not a port number", cfg.Port)
	}
	if cfg.DatabaseURL == "" {
		return config{}, errors.New("DATABASE_URL is not set")
	}

	tz := orDefault(getenv("APP_TZ"), "Asia/Almaty")
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return config{}, fmt.Errorf("APP_TZ %q is not a known time zone: %w", tz, err)
	}
	if tz == "Local" {
		// "Local" would mean whatever the host is set to, and PostgreSQL does
		// not know such a zone name.
		return config{}, errors.New(`APP_TZ must be a zone name such as Asia/Almaty, not "Local"`)
	}
	cfg.Location = loc

	for origin := range strings.SplitSeq(getenv("CORS_ALLOWED_ORIGINS"), ",") {
		// Browsers send the origin without a trailing slash.
		if origin = strings.TrimRight(strings.TrimSpace(origin), "/"); origin != "" {
			cfg.AllowedOrigins = append(cfg.AllowedOrigins, origin)
		}
	}
	return cfg, nil
}

func orDefault(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
