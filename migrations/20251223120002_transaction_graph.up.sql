CREATE TABLE IF NOT EXISTS transaction_graph (
  from_address      TEXT NOT NULL,
  to_address        TEXT NOT NULL,
  txid              TEXT NOT NULL,
  block_height      INT NOT NULL,
  value_sats        BIGINT NOT NULL,
  PRIMARY KEY (from_address, to_address, txid),
  FOREIGN KEY (txid) REFERENCES transactions(txid),
  FOREIGN KEY (block_height) REFERENCES blocks(height)
);

CREATE INDEX ON transaction_graph(from_address);
CREATE INDEX ON transaction_graph(to_address);
CREATE INDEX ON transaction_graph(txid);
CREATE INDEX ON transaction_graph(block_height);
