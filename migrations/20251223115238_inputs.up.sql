CREATE TABLE IF NOT EXISTS inputs (
  transaction_id  BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  vin             INT NOT NULL,    -- vin.index
  txid            TEXT,            -- vin.txid (NULL for coinbase)
  vout            INT,             -- vin.vout (NULL for coinbase)
  sequence        BIGINT NOT NULL, -- vin.sequence
  is_coinbase     BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (transaction_id, vin)
);

CREATE INDEX idx_inputs_tx_id ON inputs(transaction_id);
