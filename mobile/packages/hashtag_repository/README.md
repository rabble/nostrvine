# hashtag_repository

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: repository for hashtag search backed by Funnelcake APIs and shared models.

Used by: search and discovery experiences in the mobile app.

Test locally:

```bash
cd mobile/packages/hashtag_repository
flutter test
```

(`dart test` is not supported here: `funnelcake_api_client` depends on `models`, which
transitively pulls Flutter via `nostr_sdk`.)
