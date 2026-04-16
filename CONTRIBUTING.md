# Contributing To Divine

Status: Current
Validated against: `AGENTS.md`, `mobile/pubspec.yaml`, current workspace packages, and active mobile scripts on 2026-03-19.

This guide is the fast path for contributors working on the Divine mobile app and its workspace packages.

## Prerequisites

- Flutter `^3.41.1`
- Dart `^3.11.0`
- Xcode for iOS work
- Android Studio and Android SDK for Android work
- CocoaPods for Apple platform dependencies

## Setup

```bash
git clone https://github.com/divinevideo/divine-mobile.git
cd divine-mobile
cd mobile
flutter pub get
flutter doctor
```

## Worktree-First Workflow

Start every task from a clean `main` checkout:

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git worktree add .worktrees/<task-name> -b codex/<task-name> main
```

Do not start new work in a dirty checkout. Keep one task per worktree and commit the completed work before handoff.

## Where To Work

- Run Flutter commands from `mobile/`.
- Put reusable logic in the owning package under `mobile/packages/`.
- Follow the current architecture direction in [docs/STATE_MANAGEMENT.md](docs/STATE_MANAGEMENT.md) and [docs/BLOC_UI_MIGRATION_PRD.md](docs/BLOC_UI_MIGRATION_PRD.md).

## Day-To-Day Commands

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Useful app entry paths:

- `./run_dev.sh ios debug`
- `./run_dev.sh android debug`
- `./run_dev.sh macos debug`
- `./build_ios.sh release`
- `./build_android.sh release`

## Codegen And Generated Files

Run code generation when you touch `@riverpod`, `@freezed`, `@JsonSerializable`, Drift schema, or generated mocks:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Commit the relevant generated outputs with the source change.

## Testing Expectations

Start with the smallest relevant verification, then broaden when the change is cross-cutting.

Core checks:

```bash
cd mobile
flutter analyze
flutter test
```

Additional expectations:

- Run `mobile/scripts/golden.sh verify` for visual changes.
- If you touch `mobile/packages/videos_repository`, run `flutter test --coverage` from that package.
- Add or update tests next to the changed feature or package.
- Web-only branches: VM shards skip tests guarded with `kIsWeb`. Mobile CI does **not** run browser tests; before merging changes that touch `getDocumentsPath` / web document paths, run manually from `mobile/`: `flutter test test/utils/path_resolver_test.dart --platform chrome` (headless setups may need `CHROME_EXECUTABLE` and `xvfb-run -a`).

## Engineering Guardrails

- Prefer `UI -> BLoC/Cubit -> Repository -> Client` for new feature work.
- Constructor injection over hidden singletons.
- No arbitrary `Future.delayed()` in app logic.
- Never truncate Nostr IDs in code, logs, analytics, or tests.
- Reuse `divine_ui` components and `VineTheme` instead of one-off styling.
- Keep public copy direct, human, and aligned with the brand guidelines.

## Pull Requests

- Use a Conventional Commit PR title, for example `feat(settings): split settings into sub-screens`.
- Stage only task-related files.
- End with a clean `git status`.
- Open a PR once the branch is ready for review.
- If you change behavior, update the current docs or add follow-up notes to the launch hub if the change affects release readiness.

## Documentation Rules

- Current docs belong in `docs/` or `mobile/docs/`.
- Historical plans and completed investigations should be preserved but clearly marked historical.
- Before adding a new doc, check [docs/DOCUMENTATION_GUIDELINES.md](docs/DOCUMENTATION_GUIDELINES.md).
