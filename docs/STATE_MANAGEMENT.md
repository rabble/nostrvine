# State Management (Current)

Single source of truth for current state-management direction:

- `docs/BLOC_UI_MIGRATION_PRD.md`

## Summary

OpenVine is in an incremental migration where **BLoC/Cubit is the default for UI state**.
The codebase remains hybrid during transition; Riverpod still exists in some legacy/compatibility paths.

## Why this file exists

Older Riverpod migration docs were removed because they were stale and contradictory with current in-flight migration work.
If you need implementation guidance, use:

- `docs/FLUTTER.md` (engineering standards)
- `docs/BLOC_UI_MIGRATION_PRD.md` (migration rationale, best practices, PR examples)
