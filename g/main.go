package main

import (
	"log/slog"
	"os"

	"github.com/charmingruby/zgetl/config"
	"github.com/charmingruby/zgetl/database"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	}))

	cfg, err := config.Load()
	if err != nil {
		log.Error("config load failed", "error", err)
		return
	}

	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Error("database connection failed", "error", err)
		return
	}
	defer db.Close()

}
