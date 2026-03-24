# Divine

Status: Current
Validated against: repo structure, `mobile/pubspec.yaml`, active build scripts, and current settings/support flows on 2026-03-19.

Divine is a dark-mode-only short-form video app built on Nostr. This repository contains the Flutter mobile app, the shared workspace packages that power it, and the launch and engineering documentation needed to ship P1 to the App Store and Play Console.

## Current Milestone

P1 launch means the app is ready to submit to the App Store for review and to cut the matching Android release candidate. The launch-critical documentation lives in [docs/P1_LAUNCH_HUB.md](docs/P1_LAUNCH_HUB.md).

## Repository Map

- `mobile/` - Flutter app, platform projects, scripts, tests, and package workspace.
- `mobile/packages/` - Shared packages for repositories, models, Nostr clients, UI, media, auth, and utilities.
- `docs/` - Canonical repository docs, release docs, and the historical archive index.
- `mobile/docs/` - Product, protocol, testing, and mobile-specific implementation docs.
## Getting Started

```bash
cd mobile
flutter pub get
flutter run -d <device>
```

Common alternatives:

- `./run_dev.sh ios debug`
- `./run_dev.sh android debug`
- `./run_dev.sh macos debug`

## Canonical Docs

- [CONTRIBUTING.md](CONTRIBUTING.md) - setup, workflow, verification, and PR expectations
- [docs/README.md](docs/README.md) - documentation map and source-of-truth guide
- [docs/P1_LAUNCH_HUB.md](docs/P1_LAUNCH_HUB.md) - launch-critical release, review, and compliance docs
- [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md) - current state-management direction
- [docs/BLOC_UI_MIGRATION_PRD.md](docs/BLOC_UI_MIGRATION_PRD.md) - migration policy and rationale

## Daily Development

From `mobile/`:

```bash
flutter pub get
flutter analyze
flutter test
```

If you touch codegen-backed sources such as Riverpod, Freezed, JSON serialization, Drift, or mocks:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Release And Submission

Use these docs instead of older deployment notes:

- [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)
- [docs/APP_STORE_REVIEW_DOSSIER.md](docs/APP_STORE_REVIEW_DOSSIER.md)
- [mobile/docs/APPLE_REVIEW_RESPONSE.md](mobile/docs/APPLE_REVIEW_RESPONSE.md)
- [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md)

## Documentation Policy

If a doc conflicts with current code, tests, or the focused current docs above, trust the implementation first. Older plans, migration notes, and postmortems are preserved for context and tracked from [docs/archive/README.md](docs/archive/README.md).
