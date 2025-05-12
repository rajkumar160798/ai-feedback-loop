CREATE TABLE predictions (
  id TEXT PRIMARY KEY,
  f1 REAL,
  f2 REAL,
  pred INTEGER,
  ts TIMESTAMP
);

CREATE TABLE feedback (
  prediction_id TEXT,
  correct_label INTEGER,
  comment TEXT,
  ts TIMESTAMP
);
