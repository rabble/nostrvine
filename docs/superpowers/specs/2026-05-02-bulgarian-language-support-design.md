# Bulgarian Language Support Design

## Goal

Ship Bulgarian (`bg`) as a first-class language in the app, including UI
localization, app language selection, content language tagging, Android/iOS
locale declarations, generated Flutter localization code, and focused tests.

## Product And Copy Standard

Bulgarian copy must follow the diVine voice:

- direct and human, not formal government-software Bulgarian
- casual where English is casual, but not sloppy
- slightly playful for empty states, success messages, and retry affordances
- clear and calm for errors, privacy, permissions, account, auth, and safety
- no corporate phrases or pitch-deck language
- preserve product/protocol names such as Divine, diVine, Vine, Nostr, Bluesky,
  Zapstore, Blossom, and NIP references unless the source already localizes
  them
- preserve every placeholder, URL, Nostr ID, and ICU plural variable exactly

The implementation can use a machine-assisted first pass, but high-signal
strings must be reviewed and adjusted against the brand rules. A native
Bulgarian review remains the release gate before marketing this as polished.

## Architecture

Flutter already uses ARB files under `mobile/lib/l10n`, generated source under
`mobile/lib/l10n/generated`, and `AppLocalizations.supportedLocales` in
`MaterialApp.router`. Adding `app_bg.arb` and running `flutter gen-l10n` will
generate `AppLocalizationsBg` and include `Locale('bg')`.

The app has two language surfaces:

- app UI locale: `LocalePreferenceService.supportedLocales` drives the Settings
  app-language picker and persists `LocaleCubit` selections.
- content language: `LanguagePreferenceService.supportedLanguages` drives the
  content-language picker and is used by publish flow for NIP-32
  `['l', '<code>', 'ISO-639-1']` tags.

Platform locale declarations also need to match the shipped Flutter locales:

- Android per-app language picker: `mobile/android/app/src/main/res/xml/locales_config.xml`
- iOS declared localizations: `mobile/ios/Runner/Info.plist`
- Xcode known regions: `mobile/ios/Runner.xcodeproj/project.pbxproj`

## Data And Error Handling

No runtime network or repository changes are needed. Unsupported device locale
fallback remains English through `resolveAppUiLocale`. Bulgarian should match
when a device or user-selected locale has language code `bg`.

## Testing

Tests must prove:

- `AppLocalizations` loads Bulgarian and returns Bulgarian strings.
- `resolveAppUiLocale` resolves Bulgarian device preferences to `bg`.
- the UI language picker exposes `bg` as `Български`.
- the content-language picker exposes `bg` as Bulgarian.
- Android and iOS platform locale declarations include every app UI locale,
  including `bg`.
- ARB files stay structurally consistent with the English template.

Verification runs from `mobile/`:

- `flutter test test/l10n test/services/locale_preference_service_test.dart test/services/language_preference_service_test.dart`
- `flutter gen-l10n`
- `git diff --exit-code lib/l10n/generated`
