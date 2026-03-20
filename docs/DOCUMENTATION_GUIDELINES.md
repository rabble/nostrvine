# Documentation Guidelines

Status: Current
Validated against: repository documentation layout on 2026-03-19.

Use this guide before adding or rewriting docs in this repo.

## Status Labels

Every new or actively maintained doc should include two lines near the top:

- `Status: Current`, `Launch-critical`, or `Historical`
- `Validated against: ...`

Use:

- `Current` for docs contributors should trust today.
- `Launch-critical` for release, compliance, and submission docs.
- `Historical` for plans, completed investigations, and superseded architecture notes.

## Where Docs Belong

- `README.md` - project entrypoint
- `CONTRIBUTING.md` - contributor workflow and verification
- `docs/` - canonical repo docs and release docs
- `mobile/docs/` - mobile-specific product, protocol, and implementation docs
- `docs/archive/README.md` - index for historical material

## Before Adding A New Doc

1. Check whether an existing current doc should be updated instead.
2. Prefer linking to canonical docs instead of duplicating architecture or release guidance.
3. If the content is a plan, investigation, or completed implementation note, mark it `Historical`.
4. If the content affects shipping behavior or review posture, link it from [docs/P1_LAUNCH_HUB.md](P1_LAUNCH_HUB.md).

## Maintenance Rules

- If code and docs conflict, update the docs or archive them.
- Do not leave launch-critical docs branded with outdated project names unless the historical naming is the point of the document.
- Preserve historical context, but make sure readers can tell when a doc is no longer current.
- Prefer small focused docs over broad speculative ones.
