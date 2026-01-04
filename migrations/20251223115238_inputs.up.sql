CREATE TABLE IF NOT EXISTS inputs (
  id              BIGSERIAL PRIMARY KEY,
  transaction_id  BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  vin             INT NOT NULL,             -- vin.index
  prev_txid       TEXT NOT NULL DEFAULT '', -- vin.txid
  prev_vout       INT NOT NULL DEFAULT 0,   -- vin.vout
  sequence        BIGINT NOT NULL,          -- vin.sequence
  is_coinbase     BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (transaction_id, vin),
  FOREIGN KEY (prev_txid, prev_vout) REFERENCES outputs(txid, vout)
);

CREATE INDEX idx_inputs_tx_id ON inputs(transaction_id);
CREATE INDEX idx_inputs_prevout ON inputs(prev_txid, prev_vout);
CREATE INDEX idx_inputs_coinbase ON inputs(is_coinbase) WHERE is_coinbase = TRUE;
