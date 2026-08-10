# Repository Guidelines

## Repo Shape And Source Of Truth

- Most implementation work is in `mobile/`. The main Flutter entry points are `mobile/lib/main.dart` and `mobile/lib/router/app_router.dart`.
- Shared reusable logic belongs in the owning package under `mobile/packages/`, not as app-layer duplication.
- Start with current code and focused docs, especially `CONTRIBUTING.md`, `docs/STATE_MANAGEMENT.md`, `docs/BLOC_UI_MIGRATION_PRD.md`, `docs/NOSTR_EVENT_TYPES.md`, `mobile/docs/NOSTR_VIDEO_EVENTS.md`, `mobile/docs/DESIGN_SYSTEM_COMPONENTS.md`, and `mobile/docs/GOLDEN_TESTING_GUIDE.md`.
- Older docs can drift. If documentation conflicts, trust the current implementation, targeted tests, and the newest focused doc over historical notes.

## Divine Context And Brain

Before broad product, architecture, protocol, cross-repo, service-boundary, or pull-request authoring, review, or modification work, read the shared Divine context primer.

Resolve the context directory and clone it there if it is missing:

```bash
CONTEXT_DIR="${DIVINE_CONTEXT_ROOT:-../divine-context}"
[ -e "$CONTEXT_DIR/.git" ] || gh repo clone divinevideo/divine-context "$CONTEXT_DIR"
```

Use that value as `<context-dir>` below.

The `divine-context` repo is private, so cloning requires GitHub access. If clone, network, or auth fails, continue from the local repo docs and avoid cross-repo assumptions.

Before updating an existing context checkout, verify it is clean and on its default branch. If it is clean and on the default branch, update it with `git -C <context-dir> pull --ff-only`. If it is dirty, on another branch, cannot fast-forward, or network/auth fails, leave it untouched and say the context may be stale.

Read `<context-dir>/AGENT_CONTEXT.md` and follow its instructions. If unavailable, continue from the local repo docs and avoid cross-repo assumptions.

Before working on a pull request, follow `<context-dir>/PR_REVIEW.md` and use `<context-dir>/PR_REVIEW_TEAMS.md` to request the normal team and check takeover authority. Ordinary review remains open to any eligible Divine human. Before modifying a pull-request branch, enforce the mapping and every takeover gate; if the mapping cannot be read, feedback-only review may continue but automated takeover must stop. Request and verify required human review automatically when tooling permits. If the runbook is unavailable, leave the pull request open and report the blocker.

If a Divine Brain search or ask tool is available, you may use it for company memory. Treat it as optional and credentialed: tool names vary by client, and work must continue when Brain is unavailable. When Brain results influence work, cite the returned document ids. Never commit Brain credentials or expose Brain-derived sensitive content in public PRs, issues, branch names, commit messages, code comments, logs, screenshots, release notes, or externally shared agent transcripts.

## Codex Project Configuration

- Project-scoped settings and lifecycle hooks live under `.codex/`. Codex loads this layer only after the repository or worktree is trusted; use `/hooks` to review and trust changed hook definitions.
- `.claude/skills/` is the canonical source for repository skills. `.agents/skills/` is the generated Codex-compatible mirror and must not be edited directly.
- After changing a canonical skill or a Codex-specific transformation, run `.codex/scripts/sync-agent-skills.sh --write`, then `.codex/scripts/test-config.sh`. CI runs the same sync and hook regression checks.

## Worktree-First Task Workflow

> See `.claude/rules/agent_workflow.md` for detailed rationale and forbidden patterns. The bullets below are the operational summary.

- Start every new task in a **new worktree branched from `origin/main`** — never from local `main` (often stale), never from another branch or worktree.
- Fetch first, then create the worktree:
  - `git fetch origin`
  - `git worktree add .worktrees/<task-name> -b <branch-name> origin/main`
- Keep one task per worktree. Do not mix unrelated fixes, reviews, or experiments in the same tree.
- If the current checkout is dirty, do not start new work there. Commit it, stash it intentionally, or discard it intentionally first.
- **Rebase onto fresh `origin/main` before publishing or final handoff**, and whenever GitHub reports merge conflicts:
  - `git fetch origin && git rebase origin/main`
  - `git push --force-with-lease` (never `--force` without `--lease`)
- During PR review, if GitHub reports no merge conflicts and the update is only addressing review feedback, do not rebase just to refresh history. Push the review fix normally; the PR is squash-merged anyway.
- Never merge `main` into a feature branch — always rebase.

## Security

- Public issues, PRs, branch names, commit messages, screenshots, and descriptions must not mention corporate partners, customers, brands, campaign names, or other sensitive external identities unless a maintainer explicitly approves it. Use generic descriptors instead. The same applies to identifying values in code, tests, and fixtures — prefer keeping them in server-side configuration over committing them.

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

## Working On An Existing PR

> See `.claude/rules/pr_takeover.md` for the full gates. The bullets below are the operational summary. These apply whether or not the `divine-context` `PR_REVIEW.md` handbook is loaded — do not assume it is.

- **Establish authorship first**, before reading the diff, running tests, or planning a fix: `gh pr view <n> --json author,isCrossRepository,isDraft,maintainerCanModify` compared against `gh api user --jq .login`.
  `maintainerCanModify` is meaningful only for fork PRs; same-repo PRs can report `false` even when you can push.
  - **Your own PR** — not a takeover. You cannot review or approve it. Findings you can't resolve go in a regular issue comment, labelled as a blocker. There is no reviewer downstream to catch a red build.
  - **Someone else's PR, same repo** — a takeover. Clear every gate in `PR_REVIEW.md` before pushing.
  - **Fork PR** (`isCrossRepository` true) — takeover gates *plus* `maintainerCanModify`. If false, you cannot push: use suggested changes or a review comment.
  - Draft PRs and feedback-only requests are read-only unless the author explicitly asks for implementation.
- Never discover authorship by trial and error. GitHub refusing the call with `Can not request changes on your own pull request` means the triage step was skipped and every decision after it was made under the wrong model.
- **Answer every review item.** Sort each into fixed / escalated / declined and say which in the handback. An item you skip silently reads as an item you fixed. Fetch inline threads via GraphQL too — substantive findings can live entirely in the review body, or only in outdated threads.
- Flag unrequested changes separately from review fixes, especially anything with user-visible blast radius (cache-key bumps, migrations, changed defaults).
- **Do not hand back until checks are green.** After every push: `gh pr checks <n> --watch`, read the result, *then* comment. Posting "I pushed the fixes" before checks finish is forbidden. The only acceptable red handback is a failure positively proven not to come from your diff, with the breaking commit named — see the broken-`main` procedure in `.claude/rules/agent_workflow.md`.
- The author keeps the merge decision. Takeover never includes merging.

## No Technical Debt, No Failing Tests

- Do not accumulate technical debt. Fix issues in the PR that touches them; do not defer with TODOs, follow-up issues, skipped tests, or commented-out code. The only acceptable TODO is a transitional-code TODO with a tracking-issue link (see `.claude/rules/code_style.md`).
- **Assume any failing test on a feature branch is caused by that branch's diff.** Never claim flakiness, never `@Skip` to silence a failure, never push red "to see what CI says." Run affected tests + `flutter analyze` before every push. See `.claude/rules/agent_workflow.md` for the diagnostic recipe when a test fails.
- A red commit can occasionally land on `main` anyway — required checks pass but go **stale**, so PR A removing an API and PR B adding a caller can both be green and still break `main` when the second merges without re-running. Every open PR behind it then inherits the failure. That is rare and never your first hypothesis. Before claiming it, prove it: the failing symbol is outside your diff **and** `main`'s own latest run failed with the same errors (`gh run list --branch main --workflow "Mobile CI"`). Then report the breaking commit and the PR that unblocks it — do not patch someone else's fix into your PR.

## Bug-Fix Workflow

- For any bug fix, regression, flaky behavior, data inconsistency, race, cache issue, crash, or unclear reproduction report, use a structured debugging workflow before changing code. If available, use `superpowers:systematic-debugging`.
- Reproduce the issue on the current build or explain why it cannot be reproduced.
- Identify the failing layer before implementing a fix. Compare expected state against actual state at the relevant boundaries, such as API/client, repository/cache, state management, and UI.
- Avoid speculative fixes that are not tied to an observed root cause.
- When addressing PR review feedback about incorrect behavior, reproduce and root-cause the behavior before patching. Use lighter process for purely mechanical feedback such as naming, formatting, copy, or direct component swaps.
- Add or update a regression test for the confirmed failure mode when feasible.

## Architecture And State Management

- Prefer the layered flow `UI -> BLoC/Cubit -> Repository -> Client` for new feature work. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the layer map, dependency direction, the repository-owns-fallback rule, and CI enforcement.
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
- If you touch any key in an `app_*.arb` file (e.g. add a key to `mobile/lib/l10n/app_en.arb`), mirror it into every other `app_*.arb` locale — or add it to `_knownUntranslatedDebt` in `test/l10n/arb_consistency_test.dart` when translations are deferred — then run `cd mobile && flutter test test/l10n/arb_consistency_test.dart` (or the check-l10n skill). CI runs this test in the general suite, but the pre-push hook only catches it when an `app_*.arb` file changed, so do not rely on the hook alone.
- If you add any service file under `mobile/lib/services/`, add its same-named `*_test.dart` and ratchet the untested-services floor: `UPDATE_BASELINE=1 bash mobile/scripts/check_untested_services_floor.sh`, then commit the updated `mobile/scripts/baseline/untested_services.txt`. The floor may only shrink; shipping a new untested service (or deleting a service's test) fails CI (`check_untested_services_floor.sh`) and the pre-push hook. CI runs the floor check on every push, but the pre-push hook only catches a subset (service/test file add, delete, or rename), so do not rely on the hook alone.
- Dependency provenance is frozen by a shrink-only ratchet (`check_dependency_provenance.sh`, baseline `mobile/scripts/baseline/dependency_provenance.txt`, issues #3655 / #3363). It records every dependency resolved from outside pub.dev — git sources including their repository URLs, path sources, hosted packages from non-pub.dev registries, and `dependency_overrides` entries — reading **both** `mobile/pubspec.lock` (git/path/hosted sources; only the lock carries `resolved-ref`) and every tracked `pubspec.yaml` (version-only overrides resolve to `source: hosted` and leave no lockfile trace). The set may only shrink, and every entry carries a trailing `# reason` naming its tracking issue. A **movable git ref fails unconditionally, even if baselined** — pin the full 40-character SHA and keep the tag in a trailing comment (`ref: <sha> # tag v1.2.3`). After genuinely removing an override, regenerate: `UPDATE_BASELINE=1 bash mobile/scripts/check_dependency_provenance.sh`. Runs in CI only, in the `generated-files` job.
- Design-system drift is guarded by four per-file numeric-ceiling ratchets over `mobile/lib` (#6145): raw `TextStyle(` (`check_raw_textstyle_ceiling.sh`), raw colors — `Colors.*`/`CupertinoColors.*`/`Color(`/`Color.fromARGB(`/`Color.fromRGBO(`/`Color.from(`/`Color.alphaBlend(`/`HSVColor`/`HSLColor`/`ColorSwatch(`/`MaterialColor(` (`check_raw_colors_ceiling.sh`), direct Material buttons — the `ButtonStyleButton` family plus `FloatingActionButton`/`PopupMenuButton`/`DropdownButton*`/`SegmentedButton`/`ToggleButtons`/`MenuItemButton`/`SubmenuButton` (`check_material_button_ceiling.sh`), and raw dialogs/sheets — `showDialog`/`showModalBottomSheet`/`showGeneralDialog`/`showBottomSheet`/the Cupertino and adaptive variants/`DialogRoute`/`RawDialogRoute`/`ModalBottomSheetRoute` (`check_raw_dialog_ceiling.sh`). All four count **code only**: comments and string-literal bodies are stripped first by `mobile/scripts/lib/dart_code_only.awk`, so a trailing comment or a log string mentioning a token never trips the guard (pinned by `mobile/test/tools/design_system_ceiling_detectors_test.dart`). Each freezes the current count per file; the count may only shrink — a new file, a raised count, or a file dropping to zero (regenerate to lock the win) fails CI. New UI must use the sanctioned `divine_ui`/`VineTheme` replacements (`VineTheme.*Font()`, `VineTheme` colors, `DivineButton`/`DivineIconButton`, `VineBottomSheet` or a full-screen flow). After an *intentional* migration that reduces a family, regenerate its baseline and commit it: `UPDATE_BASELINE=1 bash mobile/scripts/check_<name>_ceiling.sh` (baselines under `mobile/scripts/baseline/`). These run in CI only (not the pre-push hook), mirroring the raw-`Icons.*` ratchet.
- Add or update tests alongside the change. Mirror `lib/` structure under `mobile/test/` or the relevant package `test/` directory. Never add a test under `mobile/test/unit/` (a frozen legacy bucket) or loose at the `mobile/test/` root unless it mirrors a root `lib/` file (for example `lib/main.dart` to `test/main_*_test.dart`) or tests a `test/` helper. `test/unit/` is frozen by a shrink-only ratchet (`check_test_unit_structure.sh`, baseline `mobile/scripts/baseline/test_unit_files.txt`); a new file under it fails CI. If you intentionally move a test out of `test/unit/`, shrink the baseline: `UPDATE_BASELINE=1 bash mobile/scripts/check_test_unit_structure.sh`, then commit it.
- Prefer widget and integration assertions that reflect user-visible behavior.
- For visual changes, run `mobile/scripts/golden.sh verify` and update goldens intentionally when needed.
- Run the smallest relevant verification first, then broaden if the change is cross-cutting.
- If a PR touches `mobile/packages/models`, run that package's relevant tests before pushing.
- If a PR touches `mobile/packages/videos_repository`, run `flutter test --coverage` from `mobile/packages/videos_repository` and confirm coverage still satisfies the repo requirement.

## Local Stack Development

- The local Docker stack (`local_stack/`) speaks cleartext on `10.0.2.2`, `localhost`, and `127.0.0.1`. Cleartext to those loopback hosts is permitted in every build type on all three native platforms — Android via the `<domain-config>` block in `mobile/android/app/src/main/res/xml/network_security_config.xml`, iOS via `NSAllowsLocalNetworking=true` in `mobile/ios/Runner/Info.plist`, macOS via the same key in `mobile/macos/Runner/Info.plist`. Remote cleartext is rejected on all three in every build type.
- Host resolution for local app endpoints is platform-specific: Android emulator uses `10.0.2.2`, while iOS Simulator and macOS use `localhost`. `localHost` in `mobile/lib/models/environment_config.dart` resolves the right one per platform — do not hardcode either alias in app code.
- `BLOSSOM_PUBLIC_URL` is baked into the media URLs the seeder mints, so it cannot be resolved per client. It defaults to the Android emulator alias; export `BLOSSOM_PUBLIC_URL=http://localhost:43003` before `local_stack/up.sh` when running against the iOS Simulator or macOS.
- The invite server resolves through `localHost` like every other LOCAL endpoint, so a LOCAL run reaches `http://<host>:43004` without a define. An explicit `--dart-define=INVITE_SERVER_URL` still wins — `local_stack/run_android_local.sh` passes one, which is now redundant but harmless.
- Web resolves local endpoints to `localhost`, but nothing wires a LOCAL web run: `AppEnvironment.local` is absent from the environment picker in `mobile/lib/screens/developer_options_screen.dart`, and neither web build selects it — `mobile_web_production_deploy.yml` pins `DEFAULT_ENV=PRODUCTION`, and the PR-preview build pins no `DEFAULT_ENV` at all, so it inherits the compiled `PRODUCTION` default. CORS is not the obstacle — funnelcake, the relay, and Blossom all send `Access-Control-Allow-Origin: *`, Keycast allows any `http://localhost:<port>` origin before consulting `ALLOWED_ORIGINS`, and a WebSocket handshake is not subject to CORS at all.
- User-installed CAs are not trusted in any build. If you need to proxy-debug with Charles or mitmproxy, add a single `<certificates src="user" />` line to `<trust-anchors>` in `mobile/android/app/src/main/res/xml/network_security_config.xml` in your working copy and don't commit it; CI's transport-security guard will block any commit that re-enables user-CA trust. (For iOS and macOS, plist-edit `NSAppTransportSecurity` similarly and revert before commit.)
- If you add a new exception to any native config, update `mobile/scripts/check_native_transport_security.sh` so the guard recognises the allowance. It covers four files: the Android XML plus the `Runner` plists for iOS and macOS and the iOS notification-service extension.

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
- After opening or updating a PR, wait for GitHub checks to finish (`gh pr checks <n> --watch`), fix anything red, and rerun stale semantic jobs if needed. Do not report the task complete while checks are red or still running.
- After a branch is merged or abandoned, prune the worktree and branch so stale task state does not accumulate.

## metaswarm

This repo includes a portable metaswarm project profile for agents that have the metaswarm plugin installed. Metaswarm is optional local orchestration; it does not replace this repo's GitHub Actions, review, test, or coverage policies.

### Workflow

- **Most tasks**: `$start` -- primes context, guides scoping, picks the right level of process
- **Complex features** (multi-file, spec-driven): Describe what you want built with a Definition of Done, then say: `Use the full metaswarm orchestration workflow.`

### Available Skills

Codex discovers skills by their SKILL.md `name` field. Invoke with `$name` syntax.

| Invoke | Purpose |
|---|---|
| `$start` | Begin tracked work on a task |
| `$setup` | Interactive guided setup |
| `$design-review-gate` | Trigger design review gate (5 reviewers) |
| `$pr-shepherd` | Monitor a PR through to merge |
| `$handling-pr-comments` | Handle PR review comments |
| `$brainstorming-extension` | Refine an idea with design review gate |
| `$create-issue` | Create a well-structured GitHub Issue |
| `$plan-review-gate` | Adversarial plan review (3 reviewers) |

### Quality Gates

- **Design Review Gate** -- 5-reviewer design review after design is drafted (`$design-review-gate`)
- **Plan Review Gate** -- 3 adversarial reviewers (Feasibility, Completeness, Scope & Alignment) -- ALL must PASS
- **Testing Gate** -- use the existing repo policy in `.claude/rules/testing.md` plus package-specific workflow coverage gates. Do not invent a root coverage threshold for this repo.

### Testing & Quality

- **Test-backed changes** -- add or update tests with the change according to the repo policy above. For metaswarm-led implementation plans, prefer a red/green TDD loop when it is practical and keeps the task reviewable.
- **Coverage policy** -- follow `.claude/rules/testing.md` and any package-specific `min_coverage` workflows. Run the relevant package tests and coverage checks called out by AGENTS.md.

### Workflow Enforcement

- Use design and plan review gates when a task is complex enough to warrant metaswarm orchestration.
- Run the smallest relevant verification first, then broaden when the change is cross-cutting.
- Follow the repo guardrails above: never use `--no-verify`, never `git push --force` without approval, never self-certify, and stay within file scope.
