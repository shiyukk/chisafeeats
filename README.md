# Chicago SafeEats

> Check before you order — the City of Chicago's official food-inspection results for ~49,000 places, on one map.

![Platform](https://img.shields.io/badge/iOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![UI](https://img.shields.io/badge/SwiftUI-MapKit-1572B6)
![License](https://img.shields.io/badge/license-MIT-green)

ChiSafeEats turns Chicago's official food-safety inspection data into an
interactive map. Ordering takeout, picking a place for dinner, or grabbing
groceries? Take a few seconds to see how it actually scored — no more guessing.

## Features

- 🗺️ **Interactive map** — ~49,000 restaurants, grocery stores, bakeries, and
  school kitchens, clustered and traffic-light colored by their latest result
  (🟢 pass · 🟡 pass w/ conditions · 🔴 fail · ⚪ out of business).
- 💯 **0–100 hygiene score** — distills dense official violation records into one
  comparable number, so two places take a second to compare.
- ⚠️ **Plain-language violation tags** — citations grouped into clear categories
  (pests, temperature control, handwashing…) and ranked Priority / Priority
  Foundation / Core, most critical first.
- 🕘 **Full inspection history** — every recorded inspection per venue, with
  serious past findings (rodents, sewage) flagged.
- 🔎 **Search & filters** — by name or address; filter by result, risk level, and
  facility type.
- 📍 **Nearby** — locate yourself and sort places by distance.
- 🌐 **Localized in 10 languages.**

## Stack
- iOS 26, SwiftUI + MapKit, Swift 6 strict concurrency
- [GRDB.swift](https://github.com/groue/GRDB.swift) (SQLite) — `DatabasePool` (WAL)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) project generation (`project.yml`)
- Data: [Chicago Open Data — Food Inspections](https://data.cityofchicago.org/resource/4ijn-s7e5.json)
  (Socrata SODA API) — no backend

## Build & run
```sh
xcodegen generate
open ChicagoFoodSafetyMap.xcodeproj
```
The repo ships no signing team — set your own in **Signing & Capabilities** (or a
gitignored `*.local.xcconfig`). Or build from the CLI:
```sh
xcodebuild -scheme ChicagoFoodSafetyMap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Architecture (MV — model-view, no view models)
- `Persistence/` — `DatabaseManager` (the only thing touching the DB file),
  `Migrations`, `SeedInstaller` (decompresses the bundled seed on first launch)
- `Networking/` — `SODAClient` + tolerant `InspectionDTO`
- `Sync/` — `InspectionImporter` (dedup + latest-snapshot, the single source of
  ingest truth), `SyncService` (full bootstrap + incremental delta sync)
- `Repositories/` — async query facades (viewport bbox, search, nearby, history)
- `Map/`, `Search/`, `Detail/` — SwiftUI screens
- `Resources/seed.sqlite.lzfse` — prebuilt seed (see [Tools/SEED.md](Tools/SEED.md))

Establishments are deduplicated by **venue** — a hash of normalized
name+address+zip (`"A:<hash>"`) — so a place holding several licenses collapses
into one establishment (falling back to the license number only when
name+address are missing). Each establishment carries a denormalized snapshot
of its latest inspection (tie-broken by inspection id on the same day) so the
map colors pins without a join.

## Privacy
No accounts, no analytics, no ads, no trackers. Location (if you grant it) is
used only on your device; settings stay on your device. Full
[privacy policy](https://shiyukk.github.io/chisafeeats/privacy.html).

## Data & disclaimer
All data comes from the City of Chicago Data Portal food-inspections dataset.
This is an independent app, **not affiliated with the City of Chicago**. Results
reflect conditions at inspection time only, and the 0–100 score is a derived
estimate computed by this app — not an official rating.

## License
[MIT](LICENSE) © 2026 Shiyu Liu
