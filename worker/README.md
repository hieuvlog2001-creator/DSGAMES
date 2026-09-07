# DSGames Online Catalog

This Worker provides the game catalog API and a small admin panel at `/admin`.

## 1. Create the D1 database

```bash
npx wrangler d1 create dsgames
```

Copy the returned database ID into `wrangler.toml`.

## 2. Create the schema

```bash
npx wrangler d1 execute dsgames --remote --file=./schema.sql
```

## 3. Set the admin secret

```bash
npx wrangler secret put ADMIN_TOKEN
```

Enter a long random token when prompted.

## 4. Deploy

```bash
npx wrangler deploy
```

Then open:

```text
https://YOUR-WORKER.workers.dev/admin
```

The iOS app uses:

```text
GET /api/games
```

## 5. Connect the iOS app

Open:

`DSGames/Sources/DSGamesApp.swift`

and change:

```swift
static let gamesURL = "https://YOUR-DSGAMES-WORKER.workers.dev/api/games"
```

to your real Worker URL.

The app refreshes the catalog on launch and whenever it returns to the foreground. Pull-to-refresh is also available. If the network is unavailable, the last catalog is used from local cache.
