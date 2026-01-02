CREATE TABLE IF NOT EXISTS wallets (
    id VARCHAR PRIMARY KEY,
    ref_id INTEGER NOT NULL,
    source VARCHAR(3) NOT NULL,
    name VARCHAR NOT NULL,
    email VARCHAR NOT NULL,
    balance INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_wallets_source ON wallets(source);
