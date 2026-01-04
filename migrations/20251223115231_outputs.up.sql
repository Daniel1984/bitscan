CREATE TABLE IF NOT EXISTS outputs (
  transaction_id     BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  txid               TEXT NOT NULL,
  vout               INT NOT NULL,     -- vout[i].vout
  value              BIGINT NOT NULL, -- vout[i].value * 100_000_000 if in sats, type -> BIGINT
  script_pubkey_hex  TEXT NOT NULL,    -- vout[i].scriptPubKey.hex
  script_type        TEXT NOT NULL,    -- vout[i].scriptPubKey.type
  address            TEXT,             -- vout[i].scriptPubKey.address
  PRIMARY KEY (txid, vout)
);

CREATE INDEX idx_outputs_transaction_id ON outputs(transaction_id);
CREATE INDEX idx_outputs_txid_vout ON outputs(txid, vout);
CREATE INDEX idx_outputs_address ON outputs(address) WHERE address IS NOT NULL;
CREATE INDEX idx_outputs_script_type ON outputs(script_type);
