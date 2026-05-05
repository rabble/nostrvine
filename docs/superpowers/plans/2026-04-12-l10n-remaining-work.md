# L10n Remaining Work (Post-PR #2930)

Date: 2026-04-12

## RTL Support (~89 instances)

Zero RTL-aware layout primitives in the codebase. Everything uses physical `left`/`right`.

**Blockers:**
- `main.dart:576` — `TextDirection.ltr` hardcoded at app root, prevents RTL entirely
- `divine_ui` package — 7 instances in shared components (app bar, search bar, bottom sheet)

**By category:**
- EdgeInsets.only(left:/right:): 32 in lib/, 4 in packages/
- Positioned with asymmetric left/right: ~35
- Alignment.centerLeft/Right: 13
- EdgeInsets.fromLTRB asymmetric: 2
- Hardcoded TextDirection.ltr: 3

**Priority order:** main.dart root → divine_ui → chat bubbles → feed overlay → auth screens

## Date/Time Formatting

**Critical:**
- TimeFormatter package: "now", "3m", "2h", "Today", "Yesterday" all hardcoded English
- drafts_tab.dart: `DateFormat('EEEE, MMM d yyyy h:mm a')` hardcoded English pattern
- creator_analytics_screen.dart: hardcoded ['Mon','Tue',...] day labels and "Xm ago" patterns
- divine_video_draft.dart: timeAgoString getter returns "Xd ago" etc.

**Fix:** Add ARB keys for relative time patterns, use `DateFormat.yMMMEd(locale)` named constructors

## Number Formatting

**Medium priority:**
- count_formatter package: hardcoded 'k', 'm' suffixes, '.' decimal separator
- string_utils.dart: duplicate compact number logic
- 3 more files with same pattern

**Fix:** Replace with `NumberFormat.compact(locale: locale)` from intl

## ContentLabel.displayName (22 labels)

All 22 content warning labels hardcoded English in the enum. Shown in content filters, account labels, upload flow, video overlays.

**Fix:** Add ARB keys per label, create `ContentLabel.localizedName(BuildContext)` method

## Notification Messages (10 templates)

Client-side notification messages hardcoded: "$actorName liked your video" etc. in notification_event_parser.dart and notification_service_enhanced.dart.

**Fix:** Replace with ARB parameterized strings

## Miscellaneous Hardcoded Strings (~10)

- 'Something went wrong' / 'Try again' in search error state
- 'Untitled' draft fallback
- 'None' for empty content warnings/backgrounds
