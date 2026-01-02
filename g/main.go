package main

import (
	"log/slog"
	"os"

	"github.com/charmingruby/zgetl/config"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	}))

	_, err := config.Load()
	if err != nil {
		log.Error("config load failed", "error", err)

		os.Exit(1)
	}
}
