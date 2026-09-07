-- Run once against the existing DSGames D1 database if desired.
-- The Worker also auto-creates these columns safely on requests.
ALTER TABLE licenses ADD COLUMN device_model TEXT;
ALTER TABLE licenses ADD COLUMN ios_version TEXT;
ALTER TABLE licenses ADD COLUMN last_seen_at TEXT;
