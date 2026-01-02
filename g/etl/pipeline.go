package etl

import (
	"context"
	"database/sql"
	"encoding/csv"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/oklog/ulid/v2"
)

type ETL struct {
	errCh       chan error
	extractCh   chan Record
	transformCh chan TransformedRecord
	wg          sync.WaitGroup
	log         *slog.Logger
	db          *sql.DB
	config      Config
}

type Config struct {
	BatchSize   int
	Concurrency int
}

type Record struct {
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	ID        int       `json:"id"`
	Amount    float64   `json:"amount"`
	CreatedAt time.Time `json:"created_at"`
}

type TransformedRecord struct {
	ID          string    `json:"id"`
	FullName    string    `json:"full_name"`
	EmailDomain string    `json:"email_domain"`
	Source      string    `json:"source"`
	RefID       int       `json:"ref_id"`
	Balance     int       `json:"balance"`
	ProcessedAt time.Time `json:"processed_at"`
}

func New(log *slog.Logger, db *sql.DB, cfg Config) *ETL {
	return &ETL{
		errCh:     make(chan error, 10),
		extractCh: make(chan Record, 100),
		wg:        sync.WaitGroup{},
		log:       log,
		db:        db,
		config:    cfg,
	}
}

func (e *ETL) Extract(ctx context.Context, filepath string) {
	defer close(e.extractCh)
	// defer e.wg.Done()

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
			createdAt, _ := time.Parse("2006-01-02", line[4])

			record := Record{
				ID:        id,
				Name:      line[1],
				Email:     line[2],
				Amount:    amount,
				CreatedAt: createdAt,
			}

			e.extractCh <- record
			recordCount++
		}
	}
}

func (e *ETL) Transform(ctx context.Context, workerID int) {
	defer e.wg.Done()

	for {
		select {
		case <-ctx.Done():
			e.log.Info("transformer worker stopped", "id", workerID)
			return
		case record, ok := <-e.extractCh:
			if !ok {
				e.log.Info("transformer worker finished", "id", workerID)
				return
			}

			transformed := TransformedRecord{
				ID:          ulid.Make().String(),
				FullName:    record.Name,
				EmailDomain: e.extractDomainFromEmail(record.Email),
				Source:      "Go",
				RefID:       record.ID,
				Balance:     int(record.Amount * 100),
				ProcessedAt: time.Now(),
			}

			if err := e.validateTransformation(transformed); err != nil {
				e.errCh <- fmt.Errorf("validation failed for record %d: %w", record.ID, err)
				continue
			}

			e.transformCh <- transformed
		}
	}
}

func (e *ETL) validateTransformation(record TransformedRecord) error {
	if record.Balance < 0 {
		return fmt.Errorf("balance must be positive")
	}

	return nil
}

func (e *ETL) extractDomainFromEmail(email string) string {
	return strings.Split(email, "@")[1]
}

// func (e *ETL) Load()      {}
// func (e *ETL) Run()       {}
