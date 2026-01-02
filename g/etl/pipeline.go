package etl

import (
	"context"
	"database/sql"
	"encoding/csv"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"time"
)

type ETL struct {
	errCh     chan error
	extractCh chan Record
	log       *slog.Logger
	db        *sql.DB
	config    Config
}

type Config struct {
	BatchSize   int
	Concurrency int
}

type Record struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	Amount    int       `json:"amount"`
	CreatedAt time.Time `json:"created_at"`
}

func New(log *slog.Logger, db *sql.DB, cfg Config) *ETL {
	return &ETL{
		errCh:     make(chan error, 10),
		extractCh: make(chan Record, 100),
		log:       log,
		db:        db,
		config:    cfg,
	}
}

func (e *ETL) Extract(ctx context.Context, filepath string) {
	file, err := os.Open(filepath)
	if err != nil {
		e.log.Error("failed to open raw file", "error", err)
	}

	reader := csv.NewReader(file)

	if _, err := reader.Read(); err != nil {
		e.errCh <- fmt.Errorf("failed to read header: %w", err)
		return
	}

	recordCount := 0
	for {
		select {
		case <-ctx.Done():
			e.log.Error("extraction stopped", "error", ctx.Err())
			return
		default:
			line, err := reader.Read()
			if err != nil {
				if err.Error() != "EOF" {
					e.errCh <- fmt.Errorf("error reading CSV: %w", err)
				}

				e.log.Info("records extracted", "amount", recordCount)
				return
			}

			id, _ := strconv.Atoi(line[0])
			amount, _ := strconv.ParseFloat(line[3], 64)
			amountInCents := int(amount * 100)
			createdAt, _ := time.Parse("2006-01-02", line[4])

			record := Record{
				ID:        id,
				Name:      line[1],
				Email:     line[2],
				Amount:    amountInCents,
				CreatedAt: createdAt,
			}

			e.extractCh <- record
			recordCount++
		}
	}
}

// func (e *ETL) Transform() {}
// func (e *ETL) Load()      {}
// func (e *ETL) Run()       {}
