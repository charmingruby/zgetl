package config

import (
	"github.com/caarlos0/env"
	"github.com/joho/godotenv"
)

type Config struct {
	BatchSize   int    `env:"BATCH_SIZE"`
	Concurrency int    `env:"CONCURRENCY"`
	DatabaseURL string `env:"DATABASE_URL"`
}

func Load() (Config, error) {
	_ = godotenv.Load()

	var cfg Config
	if err := env.Parse(&cfg); err != nil {
		return Config{}, err
	}

	return cfg, nil
}
