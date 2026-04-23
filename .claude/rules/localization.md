# Localization

All user-facing strings must use the l10n system. Never hardcode English strings in widgets.

---

## Using Localized Strings

Access strings via the `context.l10n` extension:

```dart
import 'package:openvine/l10n/l10n.dart';

// In a widget build method
Text(context.l10n.settingsTitle)
```

## Adding New Strings

When creating new UI, add strings to the ARB file first:

1. Add the key and English value to `mobile/lib/l10n/app_en.arb`
2. Use feature-prefixed keys: `profileFollowButton`, `feedEmptyState`, `authLoginTitle`
3. Add `@` metadata for parameterized strings with placeholders
4. Run `flutter gen-l10n` from `mobile/`
5. Use `context.l10n.keyName` in the widget

```json
{
  "feedEmptyState": "No videos yet",
  "feedVideoCount": "{count} videos",
  "@feedVideoCount": {
    "placeholders": { "count": { "type": "int" } }
  }
}
```

## Rules

- **Strings stay in the UI layer** — BLoCs emit status enums, the UI maps them to `context.l10n.xxx`
- **No error strings in BLoC state** — use status enums + `addError()`
- **`divine_ui` package stays l10n-free** — its widgets accept string params with English defaults
- **Plurals use ICU syntax** in ARB files, not conditional logic in Dart
- **Every `MaterialApp` in tests needs delegates** — use `localizationsDelegates: AppLocalizations.localizationsDelegates` and `supportedLocales: AppLocalizations.supportedLocales`
- **Never hardcode English strings in widget test assertions** — resolve the key from `AppLocalizations` instead, so the test survives copy changes and breaks loudly if the widget stops reading from l10n. Pick whichever lookup fits the test:

```dart
// Option A — direct lookup by locale (no BuildContext needed)
final l10n = lookupAppLocalizations(const Locale('en'));
expect(find.text(l10n.videoEditorAudioSegmentInstruction), findsOneWidget);

// Option B — via the pumped widget's BuildContext
final l10n = AppLocalizations.of(
  tester.element(find.byType(VideoAudioEditorTimingScreen)),
);
expect(find.text(l10n.videoEditorAudioSegmentInstruction), findsOneWidget);

// Optional but recommended — prove the widget actually reads from l10n
expect(
  find.text(lookupAppLocalizations(const Locale('de')).videoEditorAudioSegmentInstruction),
  findsNothing,
);

// Bad — hardcoded string breaks when copy changes and hides missing l10n
expect(find.text('Select the audio segment for your video'), findsOneWidget);
```

## Key Files

| File | Purpose |
|------|---------|
| `mobile/lib/l10n/app_en.arb` | English string definitions (source of truth) |
| `mobile/lib/l10n/app_es.arb` | Spanish translations |
| `mobile/lib/l10n/l10n.dart` | `context.l10n` extension |
| `mobile/lib/l10n/generated/` | Generated code (do not edit manually) |
| `mobile/l10n.yaml` | gen-l10n configuration |

---

## Running an l10n pass over existing code

When migrating a feature that was prototyped with hardcoded strings
(or when addressing review comments that flag l10n gaps), work in
this order:

1. **Inventory** — scan the target files for hardcoded user-facing
   strings. Exclude: log messages, asset paths, error messages passed
   to `addError`, test fixtures, debug `assert` messages.
2. **Check `app_en.arb` first.** Keys are often scaffolded in
   anticipation of a migration and sit unused. `grep -n "profileXxx"
   lib/l10n/app_en.arb` and `grep -rn "context.l10n.profileXxx" lib
   test | grep -v l10n/generated` to see what's defined-but-unused
   vs already-in-use.
3. **Prefer reuse.** If an existing key has the right copy, use it —
   even if its current callsite count is zero. Only add a new key
   when the copy genuinely differs (e.g. "Library" vs "My Library").
4. **Add missing keys** with `@keyName` metadata when the key takes
   placeholders or when the meaning isn't obvious from the key name:
   ```json
   "profileUserFallback": "user",
   "@profileUserFallback": {
     "description": "Generic fallback noun for a user whose display name is unknown. Used in sentences like 'Unfollow {user}?'."
   }
   ```
5. **Regenerate** via `flutter gen-l10n` from `mobile/`. Commit the
   regenerated files under `lib/l10n/generated/` with the migration.
6. **Swap call sites** to `context.l10n.xxx`. Add the l10n import
   (`package:openvine/l10n/l10n.dart`) if the file doesn't have it.
   For helpers that don't take `BuildContext`, thread it through — do
   not fetch l10n through `navigatorKey.currentContext` or similar
   workarounds.
7. **Update tests** that pump these widgets: add
   `AppLocalizations.localizationsDelegates` / `supportedLocales`
   to the test's `MaterialApp` (see `testing.md`). Any existing
   assertion on the hardcoded English string now needs to match the
   ARB value verbatim.

### Copy-alignment policy

If the code's hardcoded string differs slightly from the existing ARB
value (trailing period, capitalization, punctuation), **align the code
to the ARB value** rather than changing the ARB:

- ARB values are already translated into 16+ locales. Changing an
  English value silently drifts the English source from every
  translation.
- The design / product team owns copy; a silent translation churn in
  a review comment is not the place to ship copy changes.
- If the copy really needs to change, do it as a separate,
  clearly-scoped commit with a product note, not as an l10n-migration
  side effect.
