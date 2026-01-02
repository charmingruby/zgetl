package database

import (
	"database/sql"

	_ "github.com/lib/pq"
)

const postgresDriver = "postgres"

func Connect(url string) (*sql.DB, error) {
	return sql.Open(postgresDriver, url)
}
