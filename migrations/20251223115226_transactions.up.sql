CREATE TABLE IF NOT EXISTS transactions (
  id          BIGSERIAL PRIMARY KEY,
  block_id    BIGINT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
  txid        TEXT NOT NULL UNIQUE,
  tx_index    INT NOT NULL,
  version     INT NOT NULL,
  size        INT NOT NULL,
  vsize       INT NOT NULL,
  weight      INT NOT NULL,
  locktime    BIGINT NOT NULL,
  is_coinbase BOOLEAN NOT NULL DEFAULT FALSE,
  fee         NUMERIC NOT NULL DEFAULT 0,
  UNIQUE      (block_id, tx_index)
);

CREATE INDEX idx_transactions_block_id ON transactions(block_id);
CREATE INDEX idx_transactions_coinbase ON transactions(is_coinbase) WHERE is_coinbase = TRUE;
CREATE UNIQUE INDEX idx_transactions_txid ON transactions(txid);
