CREATE TABLE IF NOT EXISTS blocks (
  height        INT PRIMARY KEY,
  hash          TEXT UNIQUE NOT NULL,
  prev_hash     TEXT,
  time          TIMESTAMP NOT NULL,
  difficulty    NUMERIC NOT NULL,
  tx_count      INT NOT NULL DEFAULT 0
);

CREATE INDEX ON blocks(time);
CREATE INDEX ON blocks(hash);
