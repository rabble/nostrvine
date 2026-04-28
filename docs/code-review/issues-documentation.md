# Documentation Issues

Issues related to dartdoc coverage, package READMEs, and architecture documentation gaps.

Note: Root-level documentation is strong. `README.md` and `CONTRIBUTING.md` cover setup, development workflow, testing, and engineering guardrails. These issues cover the gaps below that level.

---

### 19 packages have no README
**Problem**: 19 of 44 packages in `mobile/packages/` have no `README.md`, while the other 25 follow a consistent template.

**Evidence**: Missing READMEs: `app_update_repository`, `app_version_client`, `blossom_upload_service`, `blurhash_service`, `categories_repository`, `count_formatter`, `curation_service`, `dm_repository`, `follow_repository`, `hls_auth_web_player`, `image_metadata_stripper`, `invite_api_client`, `nostr_app_bridge_repository`, `nostr_gateway`, `notification_repository`, `sounds_repository`, `tv_static_effect`, `unified_logger`, `users_repository`, `video_event_cache`, `whisper_wrapper`. The 25 existing READMEs follow a consistent template (purpose, used by, test command) validated on 2026-03-19. Notable omissions include core data packages (`notification_repository`, `sounds_repository`, `users_repository`) that new engineers would need to understand first.

**Impact**: Low. The package's `pubspec.yaml` and barrel file partially fill the gap, but missing READMEs slow onboarding and make it harder to understand package purpose without reading source code.

**Effort**: Low. The existing template is ~15 lines. Generating READMEs for 19 packages using the established format is mechanical work.

**GitHub ticket**: TBD

---

### App architecture is documented but not discoverable by humans
**Problem**: `docs/ARCHITECTURE.md` covers only the Nostr SDK internals. The full app layer structure (`UI → BLoC → Repository → Client`), dependency direction, project organization, and package extraction guidance is well-documented in `.claude/rules/architecture.md` — but that path is not where human developers would look during onboarding.

**Evidence**: `.claude/rules/architecture.md` comprehensively covers layers, dependency graph, barrel files, dependency injection, and when to extract packages. However, `CONTRIBUTING.md` references the architecture pattern without linking to it, and `docs/ARCHITECTURE.md` only describes Nostr SDK internals. A new engineer looking for "the architecture doc" would find the SDK deep-dive, not the app-level layer map.

**Impact**: Low–Medium. The content exists and is complete; the gap is discoverability for human engineers. AI assistants already consume the Claude rules automatically.

**Effort**: Low. Either add a link from `CONTRIBUTING.md` to `.claude/rules/architecture.md`, or create a thin `docs/ARCHITECTURE.md` (renamed, with the current one moved to `NOSTR_SDK_ARCHITECTURE.md`) that points to the Claude rules as the source of truth.

**GitHub ticket**: TBD
