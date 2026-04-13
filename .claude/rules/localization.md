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

## Key Files

| File | Purpose |
|------|---------|
| `mobile/lib/l10n/app_en.arb` | English string definitions (source of truth) |
| `mobile/lib/l10n/app_es.arb` | Spanish translations |
| `mobile/lib/l10n/l10n.dart` | `context.l10n` extension |
| `mobile/lib/l10n/generated/` | Generated code (do not edit manually) |
| `mobile/l10n.yaml` | gen-l10n configuration |
