# Martin Follow-up Investigation - March 6, 2026

Context: Martin's March 5, 2026 bug report included two issues that were not fixed in the blocklist/hashtag patch:

1. Video playback still feels choppy.
2. Charlie's post no longer shows the expected `Human Made` badge and instead falls through to `Not Divine`.

Log file examined: `~/Downloads/openvine_full_logs_2026-03-05T23-28-47.957077.txt`

## Playback

Relevant log lines:

- `2026-03-05T23:21:54.804948`: `Quality variant failed ... /720p - falling back to original MP4`
- `2026-03-05T23:23:44.006435`: `Quality variant failed ... /720p - falling back to original MP4`
- `2026-03-05T23:23:44.007904`: `Could not store quality fallback URL: Cannot use the Ref ... after it has been disposed`

Relevant code path:

- `lib/providers/individual_video_providers.dart:697-723`

Current behavior in that provider:

- If a `/720p` or `/480p` URL fails, the controller logs a fallback to the original MP4.
- The fallback URL is then cached through `fallbackUrlCacheProvider`.
- That cache write is wrapped in a `try/catch` because the provider may already be disposing.

Why this is a credible playback lead:

- The log shows the quality variant failing as expected.
- The next log line shows the cache write failing because the provider ref was already disposed.
- If the fallback URL is never persisted, a later provider recreation can retry the broken quality variant instead of reusing the original MP4.
- Repeated init failure and retry cycles would present as choppy or unstable playback even though a valid original MP4 exists.

What is not yet proven:

- The log does not prove that this is the only cause of Martin's choppy playback.
- It does not yet show how often the same video/controller is recreated after the failed cache write.

Recommended follow-up:

1. Move fallback URL persistence out of a disposable controller lifecycle path, or guard it behind a longer-lived service/notifier.
2. Add instrumentation for `videoId`, chosen URL, and whether the fallback cache survives controller recreation.
3. Reproduce on one affected video ID from the log and confirm whether subsequent opens still start from `/720p` after the first failure.

## Charlie `Human Made` / `Not Divine`

Relevant log facts:

- The March 5, 2026 log includes Charlie profile cache reads, but it does not include badge-specific logging.
- There is no direct evidence in the log showing which tags were present on the affected post at render time.

Relevant code paths:

- `packages/models/lib/src/video_event.dart:783-838`
- `lib/extensions/video_event_extensions.dart:68-76`
- `lib/utils/video_nostr_enrichment.dart:8-115`

Current badge logic:

- `proofModeVerificationLevel` reads `rawTags['verification']`.
- `hasProofMode` is true only when proof-related tags exist on the `VideoEvent`.
- `shouldShowNotDivineBadge` is true when the video is not hosted on a Divine domain, has no proof tags, and is not classified as an original vine.

Why Charlie can fall through to `Not Divine`:

- If the REST/API video object reaches the UI without proof tags in `rawTags`, `hasProofMode` is false.
- If original-vine metrics are also missing, `isOriginalVine` is false.
- In that state, any external video URL will render `Not Divine`.

Most likely failure mode:

- The post is being rendered from a REST video object that was not fully enriched with its Nostr tags.
- `lib/utils/video_nostr_enrichment.dart` only attempts enrichment for videos where `rawTags.length < 4`.
- If Charlie's REST object has a small set of non-proof tags but still misses `verification`, `proofmode`, or original-vine metrics, the UI can still misclassify it.
- If the relay query times out or returns no event, the original sparse REST object is also left in place.

Important scope note:

- `origin/main` on March 6, 2026 already includes `d37fc9823 Fix original vine badge classification (#1999)`.
- That upstream change helps with OG vine classification, but it does not by itself explain a missing `Human Made` badge when proof tags are absent from the rendered `VideoEvent`.

Recommended follow-up:

1. Capture the affected Charlie video as both REST JSON and raw Nostr event JSON.
2. Compare `rawTags`, `verification`, `proofmode`, and original-vine metrics before and after enrichment.
3. Decide whether enrichment eligibility should be broader than `rawTags.length < 4`, or whether badge-critical tags need a stronger merge path.
4. Add temporary badge logging for the affected event ID so the next bug report includes the exact classification inputs.
