# DM Shared-Video Save Design

## Goal

Let someone save a video directly from an existing shared-video direct
message. The action must work for both legacy `divine.video/video/...` links
and structured NIP-18 `q` references carried by NIP-17 messages.

## Scope

- Add **Save video** to the long-press actions for a full shared-video DM card.
- Keep **Copy video URL** working and make it available for structured shares,
  even when the plaintext message contains no Divine URL.
- Resolve the canonical `VideoEvent` through the same
  `VideosRepository.fetchVideoWithStatsForRouteId` path used by the preview.
- Save another creator's video with their watermark.
- Save the current user's own video without a watermark.
- Reuse the existing download, permission, settings-retry, progress, success,
  and failure sheets.
- Show existing localized "Video unavailable" feedback when resolution fails.

## Non-goals

- Sending arbitrary encrypted video-file attachments in DMs.
- Changing NIP-17, NIP-18, Blossom, or message persistence.
- Adding a permanent download button to the video card.
- Redesigning the conversation or reaction picker.
- Saving compact quoted-video reply previews; this action applies to the
  message's own full shared-video card.

## Architecture

### Shared DM video target

Introduce a small conversation-layer value object that normalizes a message's
video identity:

- stable ID from a canonical Divine URL when present;
- otherwise event ID or `d` tag from `DmSharedVideoRef`;
- author pubkey and video kind from the structured reference when available;
- author-scoped fallback route IDs for addressable videos;
- canonical Divine URL for copy-link behavior.

Both `MessageBubble` and `ConversationView` use this resolver. This removes the
current mismatch where the bubble renders a structured video card but the
long-press menu recognizes only plaintext URLs.

### Long-press action flow

`ReactionPickerOverlay` continues to own the combined reactions/actions sheet.
For a normalized full-card video target it shows:

1. Copy text
2. Copy video URL
3. Save video
4. Delete for everyone or Report, depending on message direction

Selecting **Save video** closes the action sheet, resolves the `VideoEvent`
through `VideosRepository`, and then:

- opens `showSaveOriginalSheet` when `video.pubkey` matches the authenticated
  user's full pubkey;
- otherwise resolves the cached creator profile, derives the normal Divine
  watermark text, and opens `showWatermarkDownloadSheet`.

The existing save sheets own network download, cache reuse, gallery
permissions, app-settings retry, progress, success, sharing, and errors.

### Failure behavior

- Malformed structured references degrade to a plain message unless a valid
  Divine URL is also present.
- A repository miss or exception produces the existing localized
  `notificationsVideoUnavailable` snackbar.
- Permission and download failures remain inside the established save sheets.
- Every async boundary checks that the initiating context is still mounted.

## UX Notes

- The feature stays in the established long-press interaction, avoiding a new
  icon over the dominant tap-to-open card surface.
- The action label reuses the existing localized `shareSheetSaveVideo` copy.
- Structured and URL-based shares now have identical actions.
- Resolution reuses the same repository and route fallbacks as the preview, so
  a displayed card normally resolves from local memory/cache before the save
  sheet starts its explicit download progress.

## Testing

- Unit-test URL, regular-event, addressable, malformed, and combined
  target normalization.
- Verify the preview cubit uses the normalized author-scoped fallbacks.
- Widget-test that video long-press actions show and return **Save video**.
- Widget-test that structured-reference cards receive video actions without a
  plaintext URL.
- Widget-test ownership routing: own video opens original save; another
  creator's video opens watermarked save.
- Widget-test repository misses show unavailable feedback.
- Run focused DM/save tests, localization consistency, and `flutter analyze`.

