# nostr_client

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: client abstraction layer between app repositories and the underlying Nostr SDK and local persistence.

Used by: repository packages that should not talk directly to transport details.

Test locally:

```bash
cd mobile/packages/nostr_client
flutter test
```
