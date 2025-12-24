CREATE TABLE IF NOT EXISTS address_transactions (
  id              BIGSERIAL PRIMARY KEY,
  address         TEXT NOT NULL,
  txid            TEXT NOT NULL,
  block_height    INT NOT NULL,
  is_input        BOOLEAN NOT NULL,  -- true if address is spending, false if receiving
  value_sats      BIGINT NOT NULL,
  vout_index      INT,  -- null for inputs, vout number for outputs
  vin_index       INT,  -- null for outputs, vin number for inputs
  FOREIGN KEY (txid) REFERENCES transactions(txid),
  FOREIGN KEY (block_height) REFERENCES blocks(height),
  UNIQUE(address, txid, is_input, vout_index, vin_index)
);

CREATE INDEX ON address_transactions(address, block_height DESC);
CREATE INDEX ON address_transactions(address, is_input);
CREATE INDEX ON address_transactions(txid);
CREATE INDEX ON address_transactions(block_height);

CREATE INDEX ON address_transactions(address, txid, block_height, is_input, value_sats);
