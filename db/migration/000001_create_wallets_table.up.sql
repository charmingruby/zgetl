CREATE TABLE IF NOT EXISTS wallets (
    id VARCHAR PRIMARY KEY,
    fullname VARCHAR NOT NULL,
    email_domain VARCHAR NOT NULL,
    source VARCHAR(3) NOT NULL,
    ref_id INTEGER NOT NULL,
    balance INTEGER NOT NULL,
    processed_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_wallets_source ON wallets(source);
