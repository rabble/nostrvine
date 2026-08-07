---
name: divine-relay-video-requirements
description: |
  Fix "blocked: event rejected by relay policy" errors when publishing Kind 34236
  (video) events to divine relays. Use when: (1) Kind 0 profile events succeed but
  Kind 34236 fails, (2) Generic policy rejection with no specific reason, (3) Video
  events work on other relays but fail on divine relays. The divine relay requires
  thumbnails for all video events - stricter than NIP-71 spec.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# Divine Relay Video Requirements

## Problem
Publishing Kind 34236 (short-form video) events to divine relays fails with
"blocked: event rejected by relay policy" even though the events comply with
NIP-71 spec.

## Context / Trigger Conditions
- Error message: `blocked: event rejected by relay policy`
- Kind 0 (profile) events publish successfully to the same relay
- Kind 34236 events fail on divine relays (wss://relay.poc.dvines.org, wss://relay.dvines.org)
- Events that work on other relays fail on divine relays

## Root Cause
The divine relay (funnelcake) has additional validation beyond NIP-71:

From `divine-funnelcake/crates/relay/src/relay.rs:554-564`:
```rust
// divine.video requires thumbnail for all videos (stricter than NIP-71)
// Accept: thumb tag, thumbnail tag, image tag, or imeta with image field
let has_thumb = event.get_tag("thumb").is_some()
    || event.get_tag("thumbnail").is_some()
    || event.get_tag("image").is_some()
    || has_imeta_with_image(&event);

if !has_thumb {
    // Event rejected
}
```

## Solution
Ensure video events include a thumbnail in one of these formats:

1. **Inside imeta tag** (preferred - NIP-92 compliant):
   ```
   ["imeta", "url https://...", "m video/mp4", "image https://thumbnail.jpg", ...]
   ```

2. **Standalone tag**:
   ```
   ["thumb", "https://thumbnail.jpg"]
   ["thumbnail", "https://thumbnail.jpg"]
   ["image", "https://thumbnail.jpg"]
   ```

### Getting Thumbnails from Blossom
Blossom (media.divine.video) auto-generates thumbnails for uploaded videos:
- Thumbnail URL: `https://media.divine.video/{video_sha256}.jpg`
- Generation is async - may take a few seconds after upload
- Check with HEAD request before assuming availability

## Verification
1. Ensure imeta tag contains `image https://...` field
2. Test publication: `nak event -k 34236 ... wss://relay.poc.dvines.org`
3. Verify with: `nak req -k 34236 -a {pubkey} --limit 1 wss://relay.poc.dvines.org`

## Example
```typescript
// Build imeta with thumbnail
const imetaParts = [
  `url ${videoUpload.url}`,
  "m video/mp4",
  `image ${videoUpload.url}.jpg`,  // Blossom thumbnail URL
  "dim 480x480",
  `x ${videoUpload.sha256}`,
  "duration 6"
];
tags.push(["imeta", ...imetaParts]);
```

## Notes
- This is divine-specific - other relays may accept videos without thumbnails
- The generic error message doesn't indicate which validation failed
- To debug relay rejections: read the relay source code for policy details
- Other divine relay validations in the same file:
  - Required `d` tag for addressable events
  - Required `title` tag
  - Required video source (`imeta` or `url` tag)

## Debugging Strategy
When getting generic "relay policy" rejections:
1. Test different event kinds (Kind 0 vs target kind) to isolate the issue
2. Check if the relay codebase is available (divine repos are at ~/code/divine/)
3. Search for "reject" or "blocked" in the relay handler code
4. Look for validation beyond standard NIP requirements

## Related Files
- Relay validation: `divine-funnelcake/crates/relay/src/relay.rs`
- Allowed kinds seed: `divine-funnelcake/database/migrations/000015_seed_allowed_kinds.up.sql`
- Relay config: `divine-funnelcake/crates/relay/src/config.rs`
