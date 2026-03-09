# PR Guardrails

Use these rules whenever you split work into branches or open/update PRs in this repo.

## PR Titles

- Every PR title must use Conventional Commit format: `type(scope): summary`.
- Use `fix(...)` for bug fixes, `feat(...)` for behavior additions, `docs:` for docs-only PRs, `chore(...)` for release/config cleanup, and `ci:` for workflow-only changes.
- Set the semantic title when creating the PR. Do not rely on editing it afterward.
- If a title must be fixed after the PR is already open, manually rerun the `semantic_pr` workflow because title edits do not reliably retrigger it.

## Generated Files

- If a branch changes Riverpod providers or any file that feeds generated code, run `dart run build_runner build --delete-conflicting-outputs` from `mobile/` before pushing.
- After running code generation, check `git status --short` and commit any generated files such as `*.g.dart`, `*.freezed.dart`, `hive_registrar.g.dart`, or other generated outputs.
- Do not assume a targeted `flutter analyze` pass is enough when generator-backed source files changed. CI will fail on stale generated files even if local tests pass.

## Package CI

- If a PR touches `mobile/packages/models`, run that package's relevant tests locally before pushing.
- If a PR touches `mobile/packages/videos_repository`, run the package tests with coverage from `mobile/packages/videos_repository`:
  `flutter test --coverage`
- For `videos_repository`, confirm the coverage run still satisfies the repo's 100% requirement before pushing.

## Split PR Checklist

- Verify the PR title is semantic before opening it.
- Run the generator step from `mobile/` if any generator-backed source changed.
- Run the closest local CI checks for each affected surface, not just one app-level test.
- For package PRs, run package-local checks in addition to app-level checks.
- After opening or updating a PR, inspect GitHub checks and rerun stale semantic jobs if needed.
