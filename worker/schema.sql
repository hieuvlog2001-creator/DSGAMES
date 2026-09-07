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

INSERT OR IGNORE INTO games (id,name,developer,icon,banner,description,version,category,featured,enabled,sort_order,updated_at)
VALUES ('aov','Arena of Valor','Liên Quân Mobile','aov','aov','Arena of Valor','1.0','MOBA',1,1,10,datetime('now'));
INSERT OR IGNORE INTO games (id,name,developer,icon,banner,description,version,category,featured,enabled,sort_order,updated_at)
VALUES ('cfm','CrossFire Mobile','CrossFire Legends','cfm','cfm','CrossFire Mobile','1.0','FPS',0,1,20,datetime('now'));
INSERT OR IGNORE INTO games (id,name,developer,icon,banner,description,version,category,featured,enabled,sort_order,updated_at)
VALUES ('ffmax','Free Fire MAX','Garena','ffmax','ffmax','Free Fire MAX','1.0','Battle Royale',0,1,30,datetime('now'));
