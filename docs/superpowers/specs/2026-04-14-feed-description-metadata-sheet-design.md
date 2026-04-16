# Feed Description Metadata Sheet Design

**Date:** 2026-04-14
**Status:** Approved

## Problem

Feed descriptions are truncated to three lines in the video overlay. When a description is longer than that, people cannot read the full text from the video surface. The expanded metadata sheet already exists, but the inline description does not open it.

The metadata sheet also renders the full description as plain text, which means URLs inside the description are not tappable even though the feed already supports clickable hashtags and mentions.

## Decision

Use the existing metadata sheet as the canonical "full description" surface.

- Tapping any non-empty inline description in the feed opens the existing `MetadataExpandedSheet`.
- The inline description remains visually unchanged: three-line clamp with ellipsis.
- The metadata sheet shows the full description with rich text behavior instead of plain text.
- URLs in the full description are tappable and open externally.

This keeps the interaction model simple: the feed stays compact, and the existing more-info surface becomes the place to read and interact with the full description.

## UI Behavior

### Feed overlay description

For any video with non-empty title/content text:

- Keep the current truncated text styling and layout.
- Make the description area tappable.
- Open `MetadataExpandedSheet.show(context, video)` on tap.

This applies even when the text would fit within three lines. Always-open behavior is more predictable than trying to detect truncation per layout pass.

### Metadata sheet description

In the sheet title section:

- Keep the title rendering as-is.
- Replace the plain description `Text` widget with the shared rich-text renderer used in feed text.
- Render the full description without line limits.

### Interactive text support

The rich-text renderer should support:

- hashtags
- nostr mentions
- plain `@mentions`
- plain URLs like `example.com/path`
- full URLs like `https://example.com/path`

URL taps should launch the link externally with `url_launcher`, matching other external link patterns already used in the app.

## Files In Scope

| File | Change |
|------|--------|
| `mobile/lib/screens/feed/feed_video_overlay.dart` | Make the inline description tappable and open the metadata sheet |
| `mobile/lib/widgets/clickable_hashtag_text.dart` | Add plain URL detection and external launch behavior |
| `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` | Render the full description with `ClickableHashtagText` |
| `mobile/test/screens/feed/feed_video_overlay_test.dart` | Add coverage for tapping description to open the metadata sheet |
| `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart` | Add coverage for rich description rendering in the sheet |

## Out Of Scope

- Changing the visual layout of the feed overlay
- Adding a separate "Read more" affordance
- Building a second full-description modal or route
- Adding domain warnings or custom in-app browser behavior for description URLs

## Testing

- Widget test: tapping a feed description opens the metadata sheet
- Widget test: the metadata sheet still renders full title and description
- Widget test: the metadata sheet uses the rich-text widget for descriptions so linkable content is rendered through the shared parser
- Regression test: existing feed overlay and metadata sheet tests stay green
