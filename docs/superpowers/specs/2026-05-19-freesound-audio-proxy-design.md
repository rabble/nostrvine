# Freesound Audio Proxy Design

## Summary

Add Freesound as a searchable audio source in the Divine mobile audio picker without shipping the Freesound API key in the app. Mobile keeps calling `api.divine.video`; `divine-router` splits `/api/freesound/*` traffic to a dedicated Fastly Compute sound proxy, while existing API traffic continues to pass through to `relay.divine.video` / Funnelcake.

## Goals

- Let creators search Freesound from the existing audio picker.
- Use Freesound preview audio URLs, not OAuth-protected original downloads.
- Keep Freesound credentials out of mobile binaries.
- Preserve attribution and license metadata in the sound model.
- Keep `divine-router` as the front door and routing layer, not the owner of Freesound business policy.

## Non-Goals

- Uploading sounds to Freesound.
- OAuth2 user authorization with Freesound.
- Original-quality Freesound downloads.
- Publishing Freesound sounds as Nostr Kind 1063 events in the first version.
- Replacing bundled sounds, saved sounds, or community Nostr sounds.

## Architecture

The public mobile endpoint is:

```text
GET https://api.divine.video/api/freesound/search?q=<query>&page=<page>
```

Request flow:

```text
divine-mobile
  -> api.divine.video
  -> divine-router Fastly Compute
  -> sound proxy Fastly Compute
  -> freesound.org/apiv2/search/
```

`divine-router` adds a path branch for `api.divine.video`:

- `/api/freesound/*` routes to the sound proxy backend.
- All other `/api/*` traffic keeps the current Funnelcake passthrough behavior.

The sound proxy owns:

- `FREESOUND_API_KEY` secret storage.
- Freesound request construction.
- Query validation and page-size caps.
- License filtering.
- Response trimming and normalization.
- Cache headers appropriate for Freesound rate limits.

## API Contract

### Search

```text
GET /api/freesound/search?q=<query>&page=<page>&page_size=<page_size>
```

Rules:

- `q` is required after trimming.
- `page` defaults to `1`.
- `page_size` defaults to `20` and is capped at `50`.
- The proxy requests only fields mobile needs from Freesound: `id`, `name`, `username`, `license`, `duration`, `previews`, `url`, `tags`, `created`, and `type`.
- The proxy excludes `Attribution NonCommercial` by default. The first version allows `Creative Commons 0` and `Attribution`.

Response:

```json
{
  "results": [
    {
      "id": "freesound_12345",
      "freesoundId": 12345,
      "title": "Tape rewind",
      "creator": "example_user",
      "source": "example_user via Freesound",
      "sourceUrl": "https://freesound.org/people/example_user/sounds/12345/",
      "license": "Creative Commons 0",
      "duration": 2.8,
      "previewUrl": "https://cdn.freesound.org/previews/...",
      "tags": ["rewind", "tape"]
    }
  ],
  "nextPage": 2,
  "count": 124
}
```

Errors return a small JSON object with a stable code:

```json
{
  "error": "rate_limited",
  "message": "Freesound is busy. Try again in a bit."
}
```

## Mobile Integration

Mobile adds a `FreesoundAudioClient` that calls the proxy and maps results to `AudioEvent`.

Mapping:

- `AudioEvent.id`: `freesound_<id>`
- `AudioEvent.pubkey`: a stable synthetic marker such as `freesound`
- `AudioEvent.url`: normalized `previewUrl`
- `AudioEvent.mimeType`: `audio/mpeg` for MP3 previews
- `AudioEvent.duration`: Freesound duration
- `AudioEvent.title`: Freesound name
- `AudioEvent.source`: `<username> via Freesound`

The existing preview, timing, selection, and saved-sounds flows can then treat Freesound results like other remote `AudioEvent` values.

The audio picker should add a Freesound category or show Freesound results only when search text is present. The recommended first version is a dedicated `Freesound` category so users understand they are searching outside Divine/community sounds.

## Attribution And Licensing

The UI must show `source` in the picker and saved library rows, which existing `AudioListTile` already supports. Detail surfaces should avoid routing Freesound entries through Nostr sound detail routes because they are not Kind 1063 events.

Selection and saving should preserve source, source URL, and license once the model supports those fields. If the first mobile patch cannot safely extend `AudioEvent`, the proxy-provided values should still be available in an external-source metadata field added in the same patch.

## Caching And Rate Limits

Freesound's default API limit is low enough that the proxy should cache search responses. Initial policy:

- Cache successful search responses for 5 minutes at the proxy.
- Cache normalized empty-result responses for 1 minute.
- Do not cache upstream errors except short 429 shielding if needed.
- Return deterministic query errors before calling Freesound.

## Testing

Router tests:

- `/api/freesound/search` on `api.divine.video` routes to the sound proxy backend.
- Existing `/api/search` and other Funnelcake paths still route to `relay.divine.video`.

Sound proxy tests:

- Builds the Freesound request with the token server-side.
- Rejects empty queries.
- Caps `page_size`.
- Filters noncommercial results.
- Normalizes preview URLs and attribution fields.
- Returns stable error codes for upstream 401, 429, and 5xx.

Mobile tests:

- Client maps proxy JSON into `AudioEvent`.
- Picker shows the Freesound category.
- Search result selection previews via `AudioPlaybackService`.
- Saving a Freesound result persists enough metadata to render attribution later.

## Rollout

1. Ship the sound proxy behind `/api/freesound/search`.
2. Add the router path split.
3. Add the mobile client and picker category behind a feature flag.
4. Verify production route behavior with a non-secret smoke test query.
5. Enable the feature flag after API key, caching, and attribution behavior are verified.
