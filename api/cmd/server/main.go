// Command server runs the driver shift diary API.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
	_ "time/tzdata" // the runtime image has no zoneinfo

	"driverdiary/internal/httpapi"
	"driverdiary/internal/store"
)

const shutdownTimeout = 10 * time.Second

func main() {
	healthcheck := flag.Bool("healthcheck", false, "probe /healthz of the server running in this container and exit with 0 or 1")
	flag.Parse()

	if *healthcheck {
		if err := probe(os.Getenv("PORT")); err != nil {
			fmt.Fprintln(os.Stderr, "healthcheck:", err)
			os.Exit(1)
		}
		return
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(log); err != nil {
		log.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
	cfg, err := loadConfig(os.Getenv)
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}

	// Cancelled by SIGINT or SIGTERM; also interrupts the wait for the database.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := store.Open(ctx, store.Config{
		DatabaseURL: cfg.DatabaseURL,
		Location:    cfg.Location,
		SeedFile:    cfg.TripsFile,
		Logger:      log,
	})
	if err != nil {
		return err
	}
	defer db.Close()

	srv := &http.Server{
		// All interfaces: inside a container the port is reached from outside.
		Addr: net.JoinHostPort("0.0.0.0", cfg.Port),
		Handler: httpapi.New(httpapi.Config{
			Store:          db,
			Location:       cfg.Location,
			AllowedOrigins: cfg.AllowedOrigins,
			Logger:         log,
		}),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	failed := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", srv.Addr, "tz", cfg.Location.String())
		if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
			failed <- err
		}
	}()

	select {
	case err := <-failed:
		return err
	case <-ctx.Done():
	}
	stop() // a second signal kills the process the usual way

	// Finish in-flight requests first; the deferred db.Close then runs with
	// nobody left using the pool.
	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown: %w", err)
	}
	return nil
}

// probe is the container health check: the runtime image has no shell and no
// curl, so the binary asks its own running copy.
func probe(port string) error {
	if port == "" {
		port = "8080"
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://" + net.JoinHostPort("127.0.0.1", port) + "/healthz")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("status %d", resp.StatusCode)
	}
	return nil
}
