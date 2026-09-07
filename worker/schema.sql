CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

INSERT OR IGNORE INTO settings (key,value) VALUES ('expires_at',NULL);

CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  developer TEXT NOT NULL DEFAULT '',
  icon TEXT,
  banner TEXT,
  description TEXT,
  version TEXT,
  category TEXT,
  launch_url TEXT,
  featured INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 100,
  updated_at TEXT NOT NULL
);

INSERT OR IGNORE INTO games (id,name,developer,icon,banner,description,version,category,featured,enabled,sort_order,updated_at) VALUES
('aov','Liên Quân Mobile DS','','aov','aov','Liên Quân Mobile DS','1.8','MOBA',1,1,10,datetime('now')),
('standoff2','Standoff 2 DS','','','','Standoff 2 DS','1.8','FPS',0,1,20,datetime('now')),
('wildrift','Wild Rift DS','','wr','wr','Wild Rift DS','1.8','MOBA',0,1,30,datetime('now')),
('ffth','Free Fire DS','','ffth','ffth','Free Fire DS','1.8','Battle Royale',0,1,40,datetime('now')),
('ffmax','Free Fire MAX DS','','ffmax','ffmax','Free Fire MAX DS','1.8','Battle Royale',0,1,50,datetime('now')),
('cfm','CrossFire Mobile DS','','cfm','cfm','CrossFire Mobile DS','1.8','FPS',0,1,60,datetime('now')),
('8ball','8 Ball Pool DS','','','','8 Ball Pool DS','1.8','Sports',0,1,70,datetime('now')),
('codm','Call of Duty Mobile (VNG / Global) DS','','','','Call of Duty Mobile (VNG / Global) DS','1.8','FPS',0,1,80,datetime('now'));


-- License keys: each key has its own expiration and enabled flag.
CREATE TABLE IF NOT EXISTS licenses (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL DEFAULT '',
  key_hash TEXT NOT NULL UNIQUE,
  key_prefix TEXT NOT NULL,
  key_value TEXT,
  expires_at TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_licenses_key_hash ON licenses(key_hash);
CREATE INDEX IF NOT EXISTS idx_licenses_enabled ON licenses(enabled);
