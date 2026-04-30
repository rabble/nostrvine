# blurhash_service

Status: Current
Validated against: `pubspec.yaml` on 2026-04-30.

Purpose: blurhash generation and decoding for video thumbnail placeholders. Provides `BlurhashService`, `BlurhashData`, and `BlurhashCache`.

Used by: the Flutter app to display progressive loading placeholders while video thumbnails are fetched.

## Behaviour

- Encoding runs in a background isolate via `compute` to keep the UI thread free.
- Component counts are chosen by aspect ratio: `4×7` for 9:16 portrait, `4×4` for 1:1 square.
- Decoding returns a `BlurhashData` object with pixel data, representative colours, and a gradient fallback.

## Legacy hash compatibility

Blurhashes stored in Nostr events published before PR #3684 were encoded with a 4:3 component ratio. They still render acceptably — colours are representative — but fine detail will not align with 9:16 content. This is an expected tradeoff for pre-existing events; no backfill was performed. New uploads generate hashes at the correct 9:16 dimensions.

## Test locally

```bash
cd mobile/packages/blurhash_service
flutter test
```
