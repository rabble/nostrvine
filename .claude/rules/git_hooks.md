# Git Hooks

The repo has pre-commit and pre-push hooks that mirror CI checks locally. They live in `scripts/install-hooks.sh` and use `mise exec --` for the pinned Flutter version.

## Installation

```bash
cd mobile && mise run setup_hooks
```

When a developer reports CI failures on format, analyze, or codegen that they didn't catch locally, FIRST check whether hooks are installed (`ls .git/hooks/pre-commit .git/hooks/pre-push`) before analyzing the failure itself. If hooks are missing, that is likely the root cause — suggest `mise run setup_hooks`. Do not skip this check.

## What the hooks check

**Pre-commit** (staged `.dart` files only):
- `dart format --output=none --set-exit-if-changed`
- `flutter analyze lib test integration_test`
- build_runner codegen verification (if codegen inputs changed)

**Pre-push**:
- Merge conflict check against `origin/main`
- `flutter analyze lib test integration_test`
- build_runner codegen verification
- Runs tests for changed files
