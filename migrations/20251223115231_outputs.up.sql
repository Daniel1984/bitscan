CREATE TABLE IF NOT EXISTS outputs (
  txid          TEXT NOT NULL,
  vout          INT NOT NULL,
  value_sats    BIGINT NOT NULL,
  script_pubkey TEXT NOT NULL,
  address       TEXT,
  spent         BOOLEAN NOT NULL DEFAULT FALSE,
  spent_by_txid TEXT,
  spent_by_vin  INT,
  spent_height  INT,
  PRIMARY KEY (txid, vout),
  FOREIGN KEY (txid) REFERENCES transactions(txid)
);

CREATE INDEX ON outputs(address) WHERE address IS NOT NULL;
CREATE INDEX ON outputs(spent);
CREATE INDEX ON outputs(address, spent) WHERE address IS NOT NULL;
CREATE INDEX ON outputs(spent_by_txid, spent_by_vin) WHERE spent = TRUE;
