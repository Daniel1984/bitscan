CREATE TABLE IF NOT EXISTS blocks (
  id                 BIGSERIAL PRIMARY KEY,
  height             INT NOT NULL,
  hash               TEXT NOT NULL UNIQUE,
  previous_hash      TEXT,
  next_hash          TEXT,
  chainwork          TEXT NOT NULL,
  version            INT NOT NULL,
  version_hex        TEXT NOT NULL,
  bits               TEXT NOT NULL,
  difficulty         NUMERIC NOT NULL,
  time               BIGINT NOT NULL,
  mediantime         BIGINT NOT NULL,
  stripped_size      INT NOT NULL,
  size               INT NOT NULL,
  weight             INT NOT NULL,
  fee                NUMERIC NOT NULL DEFAULT 0,
  tx_count           INT NOT NULL DEFAULT 0
);


CREATE UNIQUE INDEX blocks_height_idx ON blocks(height);
CREATE INDEX blocks_time_idx ON blocks(time);
CREATE INDEX blocks_prev_hash_idx ON blocks(previous_hash);
CREATE INDEX blocks_chainwork_idx ON blocks(chainwork);
