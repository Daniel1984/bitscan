CREATE TABLE IF NOT EXISTS inputs (
  txid              TEXT,
  vin               INT,
  prev_txid         TEXT,
  prev_vout         INT,
  script_sig        TEXT,
  sequence          INT,
  witness           TEXT[],
  PRIMARY KEY (txid, vin),
  FOREIGN KEY (prev_txid, prev_vout) REFERENCES outputs(txid, vout)
);

CREATE INDEX ON inputs(txid);
CREATE INDEX ON inputs(prev_txid, prev_vout);
CREATE INDEX ON inputs(script_sig);
