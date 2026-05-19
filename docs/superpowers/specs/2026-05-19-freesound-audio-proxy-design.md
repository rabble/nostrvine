# Provider-Backed Sound Library Design

## Summary

Add a searchable Divine sound library that can draw from first-party hosted sounds, Nostr audio events, and approved external providers such as Freesound or Openverse. Mobile keeps calling `api.divine.video`; `divine-router` splits `/api/sounds/*` traffic to a dedicated Fastly Compute sound proxy, while existing API traffic continues to pass through to `relay.divine.video` / Funnelcake.

## Goals

- Let creators search provider-backed sounds from the existing audio picker.
- Keep third-party provider credentials out of mobile binaries.
- Preserve attribution and license metadata in the sound model.
- Keep `divine-router` as the front door and routing layer, not the owner of provider business policy.
- Make Freesound and Openverse optional providers behind backend and mobile feature flags.

## Non-Goals

- Uploading sounds to external providers.
- OAuth2 user authorization with external providers.
- Original-quality third-party downloads unless an approved provider agreement explicitly allows them.
- Publishing external provider sounds as Nostr Kind 1063 events in the first version.
- Replacing bundled sounds, saved sounds, or community Nostr sounds.
- Crawling or bulk-replicating Freesound, Openverse, or any external provider catalog.

## Architecture

The public mobile endpoint is:

```text
GET https://api.divine.video/api/sounds/search?q=<query>&provider=<provider>&page=<page>
```

Request flow:

```text
divine-mobile
  -> api.divine.video
  -> divine-router Fastly Compute
  -> sound library proxy Fastly Compute
  -> first-party catalog, Funnelcake/Nostr, Freesound, or Openverse
```

`divine-router` adds a path branch for `api.divine.video`:

- `/api/sounds/*` routes to the sound library proxy backend.
- All other `/api/*` traffic keeps the current Funnelcake passthrough behavior.

The sound library proxy owns:

- External provider secret storage.
- Provider request construction.
- Query validation and page-size caps.
- License filtering.
- License normalization.
- Response trimming and normalization.
- Cache headers appropriate for provider rate limits.
- Provider enablement flags and production rollout gates.

Provider responsibilities:

- `divine`: first-party hosted and curated sounds.
- `nostr`: community Kind 1063 audio events, backed by Funnelcake/Nostr reads.
- `freesound`: preview-only external search, disabled in production until commercial API permission is confirmed.
- `openverse`: external open-media search, disabled until attribution, rate-limit, and source-platform requirements are verified.

## API Contract

### Search

```text
GET /api/sounds/search?q=<query>&provider=<provider>&page=<page>&page_size=<page_size>
```

Rules:

- `q` is required after trimming.
- `provider` defaults to `divine`; supported values are `divine`, `nostr`, `freesound`, and `openverse`.
- `page` defaults to `1`.
- `page_size` defaults to `20` and is capped at `50`.
- `q` has a fixed maximum length and only `GET` is accepted.
- External providers request only fields mobile needs.
- External providers exclude noncommercial and no-derivatives results by default.
- Clients may request a narrower `license_type` filter, but cannot expand beyond the provider's server-side allowlist.
- The first version allows public domain, CC0, and attribution-compatible licenses.
- Every returned result must include normalized license metadata or be dropped.
- Disabled providers return `404` or a stable `provider_disabled` error without contacting upstream services.

Response:

```json
{
  "results": [
    {
      "id": "freesound_12345",
      "provider": "freesound",
      "providerId": "12345",
      "title": "Tape rewind",
      "creator": "example_user",
      "source": "example_user via Freesound",
      "sourceUrl": "https://freesound.org/people/example_user/sounds/12345/",
      "license": {
        "type": "cc0",
        "name": "Creative Commons 0",
        "url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "requiresAttribution": false,
        "allowsCommercialUse": true,
        "allowsDerivatives": true
      },
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
  "message": "Sound search is busy. Try again in a bit."
}
```

## Mobile Integration

Mobile adds a sound-library client that calls the proxy and maps results to `AudioEvent`.

Mapping:

- `AudioEvent.id`: `<provider>_<providerId>` for non-Nostr provider results
- `AudioEvent.pubkey`: a stable synthetic marker such as `freesound`, `openverse`, or `divine`
- `AudioEvent.url`: normalized `previewUrl`
- `AudioEvent.mimeType`: provider file type when known, otherwise `audio/mpeg` for MP3 previews
- `AudioEvent.duration`: normalized duration in seconds
- `AudioEvent.title`: provider title
- `AudioEvent.source`: provider attribution label
- `AudioEvent.externalSource.license`: normalized license metadata

The existing preview, timing, selection, and saved-sounds flows can then treat provider results like other remote `AudioEvent` values.

The audio picker should keep dedicated categories so users understand where results come from: Divine, Community, Featured, My Sounds, and external providers as enabled. Freesound and Openverse categories remain hidden unless their provider flags are enabled.

## Attribution And Licensing

The UI must show `source` in the picker and saved library rows, which existing `AudioListTile` already supports. Detail surfaces should avoid routing non-Nostr provider entries through Nostr sound detail routes because they are not Kind 1063 events.

Selection and saving must preserve source, source URL, license, provider, and provider ID. The first mobile patch should add narrow `AudioEvent` fields or a single structured `externalSource` object for those values; attribution must not be reduced to display-only text.

Normalized license types:

- `public_domain`
- `cc0`
- `cc_by`
- `cc_by_sa`

Disallowed by default:

- Noncommercial licenses.
- No-derivatives licenses.
- Unknown or missing licenses.
- Provider-specific custom licenses until they are explicitly reviewed and allowlisted.

Provider-specific license strings must be converted to the normalized types above at the proxy. Mobile should render from normalized metadata and should not infer permissions from provider-specific strings.

## Caching And Rate Limits

External provider API limits are low enough that the proxy should cache search responses. Initial policy:

- Cache successful search responses for 5 minutes at the proxy.
- Cache normalized empty-result responses for 1 minute.
- Do not cache upstream errors except short 429 shielding if needed.
- Return deterministic query errors before calling external providers.
- Apply per-IP or platform-supported edge rate limiting to external provider paths.

## Testing

Router tests:

- `/api/sounds/search` on `api.divine.video` routes to the sound library proxy backend.
- Existing `/api/search` and other Funnelcake paths still route to `relay.divine.video`.

Sound proxy tests:

- Builds external provider requests with server-side credentials.
- Rejects empty queries.
- Caps `page_size`.
- Rejects overlong queries.
- Filters disallowed external licenses.
- Normalizes provider-specific license strings.
- Drops results with missing or unknown license metadata.
- Normalizes preview URLs and attribution fields.
- Returns `provider_disabled` without contacting disabled providers.
- Returns stable error codes for upstream 401, 429, and 5xx.

Mobile tests:

- Client maps proxy JSON into `AudioEvent`.
- Picker shows enabled provider categories and hides disabled provider categories.
- Search result selection previews via `AudioPlaybackService`.
- Saving a provider result persists normalized license metadata and enough attribution data to render attribution later.

## Rollout

1. Ship the sound library proxy and router path split behind `/api/sounds/search`.
2. Enable `divine` and `nostr` providers first.
3. Add the mobile client and provider categories behind feature flags.
4. Verify production route behavior with a non-secret smoke test query.
5. Enable Freesound only after commercial API permission, caching, and attribution behavior are verified.
6. Enable Openverse only after rate-limit, attribution, and source-platform requirements are verified.
