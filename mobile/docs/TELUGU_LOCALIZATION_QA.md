# Telugu Localization QA

Status: In progress  
Tracking issue: [#8473](https://github.com/divinevideo/divine-mobile/issues/8473)  
Locale source: `mobile/lib/l10n/app_te.arb`

This record is the release-quality gate for Telugu. Structural localization
checks cannot approve fluency, tone, meaning, or layout. Do not mark this
record complete until a fluent Telugu reviewer is named and every required
journey and device configuration has an outcome.

## Review ownership

| Role | Name | Date | Outcome |
| --- | --- | --- | --- |
| Fluent Telugu linguistic reviewer | Not assigned | — | Pending |
| Android visual QA | Not assigned | — | Pending |
| iOS visual QA | Not assigned | — | Pending |

## Linguistic standard

- Use natural contemporary Telugu rather than literal English syntax.
- Address the reader with polite-neutral `మీరు` and respectful plural verb
  forms unless the context clearly requires something else.
- Prefer established Telugu UI language where it is clearer than English
  transliteration.
- Keep Divine, Nostr protocol terms, URLs, identifiers, and placeholder names
  unchanged where translation would alter their identity or validity.
- Treat authentication, permissions, safety, reporting, privacy, recovery,
  and account deletion as high-risk copy requiring explicit reviewer approval.

Record linguistic findings below. Each resolved finding must name the ARB key,
the approved Telugu replacement, and the reviewer who approved it.

| ARB key | Finding | Approved replacement | Reviewer | Status |
| --- | --- | --- | --- | --- |
| — | — | — | — | Pending review |

## Journey checklist

For each journey, check natural phrasing, consistent address, untranslated or
unnecessarily transliterated English, placeholder agreement, plural output,
clipping, overflow, and controls obscured by text.

| Journey | Linguistic review | Android | iOS | Findings resolved |
| --- | --- | --- | --- | --- |
| Onboarding, invite, and authentication | Pending | Pending | Pending | Pending |
| Home feed and feed tuning | Pending | Pending | Pending | Pending |
| Search, discovery, and people lists | Pending | Pending | Pending | Pending |
| Profiles, follows, and social actions | Pending | Pending | Pending | Pending |
| Notifications and direct messages | Pending | Pending | Pending | Pending |
| Recording and camera permissions | Pending | Pending | Pending | Pending |
| Video editor and clip recovery | Pending | Pending | Pending | Pending |
| Upload, publishing, and sharing | Pending | Pending | Pending | Pending |
| Settings and both language pickers | Pending | Pending | Pending | Pending |
| Privacy, safety, reporting, and moderation | Pending | Pending | Pending | Pending |
| Account recovery, export, and deletion | Pending | Pending | Pending | Pending |
| Empty, loading, error, and retry states | Pending | Pending | Pending | Pending |

## Visual matrix

Use production fonts and a release-mode build. Exercise at least the compact
screen configurations below; additional devices may be recorded as extra rows.

| Platform | Form factor | Appearance | Text scale | Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Android | Compact phone | Light | 1.0× | Pending | — |
| Android | Compact phone | Dark | 1.0× | Pending | — |
| Android | Compact phone | Light | Largest supported | Pending | — |
| Android | Compact phone | Dark | Largest supported | Pending | — |
| iOS | Compact phone | Light | 1.0× | Pending | — |
| iOS | Compact phone | Dark | 1.0× | Pending | — |
| iOS | Compact phone | Light | Largest supported | Pending | — |
| iOS | Compact phone | Dark | Largest supported | Pending | — |

Evidence must be scrubbed of private messages, account identifiers, and other
user data before it is linked from this record.

## Required verification after corrections

From `mobile/`:

```bash
flutter gen-l10n
flutter test test/l10n test/assets/sticker_manifest_consistency_test.dart test/services/locale_preference_service_test.dart test/services/language_preference_service_test.dart
flutter analyze
bash scripts/check_orphaned_arb_key_floor.sh
bash scripts/check_maestro_copy_drift.sh
bash scripts/check_l10n_delegates_ceiling.sh
```

The generated localization files must have no diff after regeneration, all CI
checks must pass, and the fluent reviewer must approve the final corrected
catalog before this record or #8473 is completed.
