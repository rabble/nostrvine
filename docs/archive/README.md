# Historical Documentation Index

Status: Historical
Validated against: repo documentation layout on 2026-03-19.

This index tracks documentation that is preserved for context but is not the current source of truth for P1 launch work.

## Historical Buckets

- `docs/plans/` - historical implementation plans
- `docs/pr-fix-plans/` - PR-specific follow-up notes
- `docs/superpowers/` - design/spec/plan artifacts from earlier planning workflows
- `mobile/docs/plans/` - mobile feature plans and implementation notes

## Historical Standalone Docs

These older docs are intentionally preserved but should not drive launch decisions without checking current code and current docs first:

- deployment notes still tied to OpenVine or web-first flows
- completed migration reports and postmortems
- broad architecture analyses that predate the current BLoC migration direction
- older settings/navigation plans that reference deleted screens or drawers

## How To Use Historical Docs Safely

1. Start with [docs/README.md](../README.md).
2. Confirm whether a newer current doc exists.
3. Treat historical docs as context, not execution instructions.
4. If a historical doc is still useful, keep it but add a clear `Historical` banner.
