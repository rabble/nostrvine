# Repository Guidelines

## Repo Shape And Source Of Truth

- Most implementation work is in `mobile/`. The main Flutter entry points are `mobile/lib/main.dart` and `mobile/lib/router/app_router.dart`.
- Shared reusable logic belongs in the owning package under `mobile/packages/`, not as app-layer duplication.
- Start with current code and focused docs, especially `CONTRIBUTING.md`, `docs/STATE_MANAGEMENT.md`, `docs/BLOC_UI_MIGRATION_PRD.md`, `docs/NOSTR_EVENT_TYPES.md`, `mobile/docs/NOSTR_VIDEO_EVENTS.md`, `mobile/docs/DESIGN_SYSTEM_COMPONENTS.md`, and `mobile/docs/GOLDEN_TESTING_GUIDE.md`.
- Older docs can drift. If documentation conflicts, trust the current implementation, targeted tests, and the newest focused doc over historical notes.

## Worktree-First Task Workflow

> See `.claude/rules/agent_workflow.md` for detailed rationale and forbidden patterns. The bullets below are the operational summary.

- Start every new task in a **new worktree branched from `origin/main`** — never from local `main` (often stale), never from another branch or worktree.
- Fetch first, then create the worktree:
  - `git fetch origin`
  - `git worktree add .worktrees/<task-name> -b <branch-name> origin/main`
- Keep one task per worktree. Do not mix unrelated fixes, reviews, or experiments in the same tree.
- If the current checkout is dirty, do not start new work there. Commit it, stash it intentionally, or discard it intentionally first.
- **Rebase onto fresh `origin/main` before every push**, even on a branch you've already pushed:
  - `git fetch origin && git rebase origin/main`
  - `git push --force-with-lease` (never `--force` without `--lease`)
- Never merge `main` into a feature branch — always rebase.

## PR Guardrails

- Every PR title must use Conventional Commit format: `type(scope): summary` or `docs: summary` for docs-only PRs.
- Set the semantic title when creating the PR. Do not rely on editing it afterward.
- If a PR title must be fixed after opening, rerun the `semantic_pr` workflow because title edits do not reliably retrigger it.
- **Every PR targets `main`. Never stack PRs.** When features are interdependent, ship them as **one combined PR** with clearly delineated commits and a description that calls out each feature separately. Never `gh pr create --base <other-branch>`.
- A task is not complete if the intended changes are still uncommitted.
- Stage only the files that belong to the task. Avoid broad staging when the worktree contains unrelated changes.
- End each task with a clean `git status` except for changes that are explicitly still in progress and clearly called out.
- Commit the completed work on the task branch before handoff.
- Open a pull request for that branch once the change is ready for review. Do not leave finished work sitting only in a local branch or worktree.
- Keep PRs focused and reviewable. If two pieces of work are *truly independent*, split them into separate PRs each targeting `main`. If they depend on each other, **combine them into one PR** rather than splitting and stacking.

## No Technical Debt, No Failing Tests

- Do not accumulate technical debt. Fix issues in the PR that touches them; do not defer with TODOs, follow-up issues, skipped tests, or commented-out code. The only acceptable TODO is a transitional-code TODO with a tracking-issue link (see `.claude/rules/code_style.md`).
- **`origin/main` always passes.** Any failing test on a feature branch is caused by that branch's diff. Never claim flakiness, never `@Skip` to silence a failure, never push red "to see what CI says." Run affected tests + `flutter analyze` before every push. See `.claude/rules/agent_workflow.md` for the diagnostic recipe when a test fails.

## Architecture And State Management

- Prefer the layered flow `UI -> BLoC/Cubit -> Repository -> Client` for new feature work.
- Repositories and blocs should not depend on Flutter UI types.
- Prefer constructor injection over hidden singleton-style dependencies.
- New UI state should use BLoC/Cubit. Riverpod is legacy and compatibility glue while the migration is in progress.
- When touching Riverpod-heavy UI paths, migrate opportunistically toward BLoC if the scope is reasonable and the change stays reviewable.
- Keep migrations incremental and test-backed. Use `docs/BLOC_UI_MIGRATION_PRD.md` as the migration source of truth.
- Prefer small widget classes over helper methods that return `Widget`.
- For screens with non-trivial dependency wiring, prefer a Page/View split.

## UI, Routing, And Product Copy

- Follow the existing `go_router` patterns in `mobile/lib/router/app_router.dart`.
- Prefer full-screen flows over introducing new dialogs or bottom sheets unless the task explicitly calls for one or the existing UX already uses that pattern.
- Divine is dark-mode only. Use `VineTheme` and existing components from `mobile/packages/divine_ui` instead of raw `Colors.*` values or one-off styling.
- Reuse shared components like `DivineButton`, `DivineIconButton`, `DivineAuthTextField`, and `VineBottomSheet` when they fit the job.
- When changing user-facing copy, align with `brand-guidelines/AGENT_QUICK_REFERENCE.md` and `brand-guidelines/TONE_OF_VOICE.md`: direct, human, slightly playful, and never corporate.

## Nostr And Async Rules

- Never truncate Nostr IDs in code, logs, tests, analytics, or debug output. Use full values and let UI layout handle overflow visually.
- Prefer existing NIPs, kinds, and tags over inventing new protocol shapes. Check the current code and the Nostr docs in this repo before changing event behavior.
- Treat protocol docs as advisory when they conflict with code; some historical docs are stale.
- Avoid introducing arbitrary `Future.delayed()` calls in app code. Prefer explicit async coordination, callbacks, streams, completers, or timers with a clear reason.

## Verification And Generated Code

- Run work from `mobile/` for Flutter commands.
- If dependencies or the workspace change, run `flutter pub get`.
- If you touch `@riverpod`, `@freezed`, `@JsonSerializable`, `@GenerateMocks`, Drift schema, or other generated code inputs, run `dart run build_runner build --delete-conflicting-outputs` and commit the generated outputs.
- After generation, check `git status --short` and commit relevant files such as `*.g.dart`, `*.freezed.dart`, `hive_registrar.g.dart`, or other generated artifacts.
- Do not assume a targeted analyze pass is enough when generator-backed source changed. CI will fail on stale generated files even if local tests pass.
- Add or update tests alongside the change. Mirror `lib/` structure under `mobile/test/` or the relevant package `test/` directory.
- Prefer widget and integration assertions that reflect user-visible behavior.
- For visual changes, run `mobile/scripts/golden.sh verify` and update goldens intentionally when needed.
- Run the smallest relevant verification first, then broaden if the change is cross-cutting.
- If a PR touches `mobile/packages/models`, run that package's relevant tests before pushing.
- If a PR touches `mobile/packages/videos_repository`, run `flutter test --coverage` from `mobile/packages/videos_repository` and confirm coverage still satisfies the repo requirement.

## Local Stack Development

- The local Docker stack (`local_stack/`) speaks cleartext on `10.0.2.2`, `localhost`, and `127.0.0.1`. Cleartext to those loopback hosts is permitted in every build type on both platforms — Android via the `<domain-config>` block in `mobile/android/app/src/main/res/xml/network_security_config.xml`, iOS via `NSAllowsLocalNetworking=true` in `mobile/ios/Runner/Info.plist`. Remote cleartext is rejected on both platforms in every build type.
- Either Android emulator (`10.0.2.2` → host) or iOS Simulator (`localhost` → host) works against the local stack out of the box.
- User-installed CAs are not trusted in any build. If you need to proxy-debug with Charles or mitmproxy, add a single `<certificates src="user" />` line to `<trust-anchors>` in `mobile/android/app/src/main/res/xml/network_security_config.xml` in your working copy and don't commit it; CI's transport-security guard will block any commit that re-enables user-CA trust. (For iOS, plist-edit `NSAppTransportSecurity` similarly and revert before commit.)
- If you add a new exception to either native config, update `mobile/scripts/check_native_transport_security.sh` so the guard recognises the allowance.

## Zapstore Publishing Notes

- Do not complicate Zapstore publish handoff. Let Rabble run `zsp` directly unless explicitly asked to wrap or automate it.
- Never ask Rabble to paste an `nsec` into chat or into a shell command that would land in history.
- If `zsp` selects the wrong release, stop and fix the release source/version issue before signing. Do not continue to preview/sign.
- Divine `1.0.9` was a GitHub prerelease, so `zsp` selected `1.0.8` unless `--pre-release` was passed or a local APK/config path forced the exact APK.
- Before telling Rabble to sign, verify the `zsp` fetch output shows the intended APK version, for example `Version: 1.0.9 (...)`.

## Clean Workspace Expectations

- Do not leave untracked or modified files around after a task unless they are part of the intentional diff.
- Delete temporary debugging artifacts before commit.
- If a generated file must be committed, make sure it is reproducible and relevant to the change.
- Before opening the PR, review the diff and remove stray edits, generated junk, logs, scratch files, and half-finished experiments.
- After opening or updating a PR, inspect GitHub checks and rerun stale semantic jobs if needed.
- After a branch is merged or abandoned, prune the worktree and branch so stale task state does not accumulate.
