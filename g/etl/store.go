package etl

import (
	"context"
	"database/sql"
)

type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	return &Store{
		db: db,
	}
}

func (s *Store) InsertBatch(ctx context.Context, records []TransformedRecord) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.PrepareContext(ctx, `
		INSERT INTO processed_records (id, fullname, email_domain, source, ref_id, balance, processed_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, r := range records {
		_, err := stmt.ExecContext(ctx,
			r.ID,
			r.FullName,
			r.EmailDomain,
			r.Source,
			r.RefID,
			r.Balance,
			r.ProcessedAt,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}
