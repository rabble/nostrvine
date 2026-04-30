# blurhash_service

Status: Current
Validated against: `pubspec.yaml` on 2026-04-30.

Purpose: blurhash generation and decoding for video thumbnail placeholders. Provides `BlurhashService`, `BlurhashData`, `BlurhashCache`, `BlurhashException`, and the `VineContentType` enum consumed by `getBlurhashForContentType`.

Used by: the Flutter app to display progressive loading placeholders while video thumbnails are fetched.

## Behaviour

- Encoding runs in a background isolate via `compute` to keep the UI thread free. (`generateBlurhashFromImage` performs the PNG conversion on the caller's thread before delegating — keep it off the UI path for large images.)
- Component counts are chosen by aspect ratio: `4×7` for portrait (ratio < 0.9), `4×4` for square or landscape (ratio ≥ 0.9).
- Decoding returns a `BlurhashData` object with pixel data, representative colours, and a gradient fallback.
- `BlurhashCache` provides a bounded in-memory cache of decoded blurhash data with expiry-based eviction.

## Legacy hash compatibility

Blurhashes stored in Nostr events published before PR #3684 were encoded with `4×3` components (the previous defaults), regardless of the source aspect ratio. They still render acceptably — colours are representative — but fine detail will not align with 9:16 content. This is an expected tradeoff for pre-existing events; no backfill was performed. New uploads generate hashes at the correct 9:16 dimensions.

## Test locally

```bash
cd mobile/packages/blurhash_service
flutter test
```
