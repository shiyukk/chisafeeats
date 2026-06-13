# Rebuilding the bundled seed database

The app ships `Resources/seed.sqlite.lzfse` — a compressed snapshot of the full
Chicago food-inspection dataset so the app is fully populated offline on first
launch. Regenerate it whenever you want fresher data or change the schema.

Currently the seed is produced by running the app's own `fullBootstrap` in the
simulator (reuses the exact importer logic — no separate tool to drift), then
extracting and trimming the result.

## Steps

1. Temporarily ensure the app will do a full download on launch: uninstall it
   so there's no cached DB (and no bundled seed, or it'll just install that):
   ```
   xcrun simctl uninstall "iPhone 17 Pro" com.placeholder.chicagofoodsafety
   ```
   (Temporarily move `Resources/seed.sqlite.lzfse` aside if present, and
   `xcodegen generate`, so the clean install has no seed and runs fullBootstrap.)

2. Build, install, launch; wait for `fullBootstrap` to ingest all ~311k rows
   (`sync_meta.last_sync_date` gets set on completion).

3. Checkpoint + VACUUM the container DB into a clean file:
   ```
   DB=$(xcrun simctl get_app_container "iPhone 17 Pro" com.placeholder.chicagofoodsafety data)/Library/Application\ Support/chicago_food_safety.sqlite
   sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);"
   sqlite3 "$DB" "VACUUM INTO '/tmp/seed.sqlite';"
   ```

4. Trim violation text older than 3 years to keep the seed small (kept: all
   establishments, all inspection date/result history, recent violation detail):
   ```
   sqlite3 /tmp/seed.sqlite "UPDATE inspection SET violations_raw = NULL WHERE inspection_date < '2023-01-01';"
   sqlite3 /tmp/seed.sqlite "VACUUM INTO '/tmp/seed_trim.sqlite';"
   ```

5. Compress and place as the bundled resource:
   ```
   swift Tools/compress_seed.swift /tmp/seed_trim.sqlite Resources/seed.sqlite.lzfse
   xcodegen generate
   ```

## Current snapshot
- Source rows: 311,449 inspections → 48,936 establishments
- Trimmed seed: ~111 MB uncompressed → ~22 MB LZFSE
- Old (<2023) inspections keep date/result; their violation text is fetched
  on demand when online (TODO: on-demand violation fetch in detail screen).
