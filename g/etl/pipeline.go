package etl

import "database/sql"

type ETL struct {
	db     *sql.DB
	config Config
}

type Config struct {
	BatchSize   int
	Concurrency int
}

func New(db *sql.DB, cfg Config) *ETL {
	return &ETL{
		db:     db,
		config: cfg,
	}
}

// func (e *ETL) Extract()   {}
// func (e *ETL) Transform() {}
// func (e *ETL) Load()      {}
// func (e *ETL) Run()       {}
