package main

import (
	"slices"
	"strings"
	"testing"
	_ "time/tzdata"
)

func env(vars map[string]string) func(string) string {
	return func(key string) string { return vars[key] }
}

func TestLoadConfigDefaults(t *testing.T) {
	cfg, err := loadConfig(env(map[string]string{"DATABASE_URL": "postgres://u:p@db/diary"}))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "8080" || cfg.TripsFile != "data/trips.json" || cfg.Location.String() != "Asia/Almaty" {
		t.Errorf("defaults = %+v", cfg)
	}
	if len(cfg.AllowedOrigins) != 0 {
		t.Errorf("AllowedOrigins = %v, want none", cfg.AllowedOrigins)
	}
}

func TestLoadConfigFromEnv(t *testing.T) {
	cfg, err := loadConfig(env(map[string]string{
		"DATABASE_URL":         "postgres://u:p@db/diary",
		"PORT":                 "9000",
		"APP_TZ":               "Europe/Moscow",
		"TRIPS_FILE":           "/data/trips.json",
		"CORS_ALLOWED_ORIGINS": " https://demo.example/ , http://localhost:5000,,",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Port != "9000" || cfg.TripsFile != "/data/trips.json" || cfg.Location.String() != "Europe/Moscow" {
		t.Errorf("config = %+v", cfg)
	}
	if want := []string{"https://demo.example", "http://localhost:5000"}; !slices.Equal(cfg.AllowedOrigins, want) {
		t.Errorf("AllowedOrigins = %v, want %v", cfg.AllowedOrigins, want)
	}
}

func TestLoadConfigErrors(t *testing.T) {
	tests := []struct {
		name    string
		vars    map[string]string
		wantErr string
	}{
		{"no database url", map[string]string{}, "DATABASE_URL"},
		{"unknown zone", map[string]string{"DATABASE_URL": "x", "APP_TZ": "Mars/Olympus"}, "APP_TZ"},
		{"local zone", map[string]string{"DATABASE_URL": "x", "APP_TZ": "Local"}, "APP_TZ"},
		{"port is not a number", map[string]string{"DATABASE_URL": "x", "PORT": "http"}, "PORT"},
		{"port out of range", map[string]string{"DATABASE_URL": "x", "PORT": "70000"}, "PORT"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := loadConfig(env(tt.vars))
			if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error = %v, want it to mention %s", err, tt.wantErr)
			}
		})
	}
}
