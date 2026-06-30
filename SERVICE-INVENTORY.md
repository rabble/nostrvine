# Service Inventory

This is a lightweight repo inventory for agents and contributors. Current code, focused docs, and tests remain the source of truth when this file drifts.

## App Surfaces

| Surface | Path | Responsibility |
|---------|------|----------------|
| Flutter app | `mobile/lib/` | Main diVine mobile app, routing, screens, feature wiring |
| Router | `mobile/lib/router/app_router.dart` | `go_router` route definitions and navigation wiring |
| Shared UI | `mobile/packages/divine_ui/` | Reusable dark-mode UI components and theme primitives |

## Knowledge Sources

| Source | Path / Tool | Responsibility |
|--------|-------------|----------------|
| Repo instructions | `AGENTS.md` | Task workflow, verification rules, and optional metaswarm usage |
| Divine Context | `${DIVINE_CONTEXT_ROOT:-../divine-context}/AGENT_CONTEXT.md` | Optional sibling repo with cross-repo product goals, architecture, Nostr assumptions, terminology, and service catalog |
| Divine Brain | developer-local MCP tools when configured | Optional company memory for decisions, Slack/Drive/GitHub/Gmail/Figma context, infra inventory, incidents, and customer themes |

## Packages

| Package Area | Path | Responsibility |
|--------------|------|----------------|
| Repositories | `mobile/packages/*_repository/` | Data access and feature repositories used by app BLoCs/Cubits |
| Clients | `mobile/packages/*_client/` | API or platform client boundaries |
| Models | `mobile/packages/models/` | Shared model types and generated serialization outputs |
| Nostr | `mobile/packages/nostr_*` | Nostr event, relay, key, and app-bridge behavior |
| Media | `mobile/packages/divine_video_player/`, `mobile/packages/divine_camera/`, `mobile/packages/media_cache/` | Video playback, capture, and cache behavior |

## Established Patterns

- Most implementation work starts in `mobile/`; run Flutter commands from that directory.
- New UI state should use BLoC/Cubit. Riverpod remains legacy compatibility glue during migration.
- Prefer the layered flow `UI -> BLoC/Cubit -> Repository -> Client`.
- Shared reusable logic belongs in the owning package under `mobile/packages/`.
- Do not truncate Nostr IDs in code, logs, tests, analytics, or debug output.
- For non-local company context, use Divine Brain when it is configured before guessing or inventing rationale.
- Keep Divine Brain credentials out of repo files; auth belongs in developer-local/global MCP configuration.
