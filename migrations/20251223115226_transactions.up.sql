CREATE TABLE IF NOT EXISTS transactions (
  txid          TEXT PRIMARY KEY,
  block_height  INT REFERENCES blocks(height),
  tx_index      INT NOT NULL,
  is_coinbase   BOOLEAN NOT NULL DEFAULT FALSE,
  fee_sats      BIGINT DEFAULT 0,
  UNIQUE(block_height, tx_index)
);

CREATE INDEX ON transactions(block_height);
CREATE INDEX ON transactions(block_height, tx_index);
CREATE INDEX ON transactions(is_coinbase);
