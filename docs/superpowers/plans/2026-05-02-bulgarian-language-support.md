# Bulgarian Language Support Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full Bulgarian language support across Flutter UI localization, app/content language pickers, Android/iOS locale declarations, generated l10n, and tests.

**Architecture:** Add `app_bg.arb` beside the existing ARB files and let Flutter `gen-l10n` produce `AppLocalizationsBg` plus `Locale('bg')`. Wire `bg` into the two existing language services and platform locale declarations. Keep fallback behavior unchanged.

**Tech Stack:** Flutter, Dart, ARB/gen-l10n, BLoC `LocaleCubit`, SharedPreferences-backed language services, Android XML locale config, iOS plist/Xcode project locale metadata.

**Spec:** `docs/superpowers/specs/2026-05-02-bulgarian-language-support-design.md`

---

## Chunk 1: Tests First

### Task 1: Add Failing Bulgarian Locale Coverage

**Files:**
- Modify: `mobile/test/l10n/l10n_test.dart`
- Modify: `mobile/test/l10n/resolve_app_ui_locale_test.dart`
- Modify: `mobile/test/services/locale_preference_service_test.dart`
- Modify: `mobile/test/services/language_preference_service_test.dart`
- Create: `mobile/test/l10n/platform_locale_declarations_test.dart`

- [ ] **Step 1: Add `bg` localization loading test**

In `mobile/test/l10n/l10n_test.dart`, add a widget test that pumps
`MaterialApp(locale: const Locale('bg'))` and expects:

```dart
expect(l10n.settingsTitle, equals('Настройки'));
expect(l10n.settingsAppLanguageTitle, equals('Език на приложението'));
```

- [ ] **Step 2: Add locale resolution test**

In `mobile/test/l10n/resolve_app_ui_locale_test.dart`, add:

```dart
test('matches supported Bulgarian', () {
  final locale = resolveAppUiLocale(const [Locale('bg', 'BG')], supported);
  expect(locale.languageCode, 'bg');
});
```

- [ ] **Step 3: Add app language picker service test**

In `mobile/test/services/locale_preference_service_test.dart`, include `bg` in
the expected supported locale keys and assert:

```dart
expect(LocalePreferenceService.supportedLocales['bg'], 'Български');
```

- [ ] **Step 4: Add content language service test**

In `mobile/test/services/language_preference_service_test.dart`, assert:

```dart
expect(LanguagePreferenceService.displayNameFor('bg'), equals('Bulgarian'));
```

- [ ] **Step 5: Add platform declaration test**

Create `mobile/test/l10n/platform_locale_declarations_test.dart` that parses:

- `lib/l10n/generated/app_localizations.dart`
- `android/app/src/main/res/xml/locales_config.xml`
- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`

and verifies `bg` is present in Android locales, iOS `CFBundleLocalizations`,
and Xcode `knownRegions`. Keep the parser small and deterministic; avoid
pulling in XML/plist packages for this narrow test.

- [ ] **Step 6: Run tests and verify RED**

Run from `mobile/`:

```bash
flutter test test/l10n test/services/locale_preference_service_test.dart test/services/language_preference_service_test.dart
```

Expected: fail because `bg` is not generated/listed yet.

## Chunk 2: Locale Implementation

### Task 2: Add Bulgarian ARB And Locale Wiring

**Files:**
- Create: `mobile/lib/l10n/app_bg.arb`
- Modify: `mobile/lib/services/locale_preference_service.dart`
- Modify: `mobile/lib/services/language_preference_service.dart`
- Modify: `mobile/android/app/src/main/res/xml/locales_config.xml`
- Modify: `mobile/ios/Runner/Info.plist`
- Modify: `mobile/ios/Runner.xcodeproj/project.pbxproj`
- Generated: `mobile/lib/l10n/generated/app_localizations.dart`
- Generated: `mobile/lib/l10n/generated/app_localizations_bg.dart`

- [ ] **Step 1: Create Bulgarian ARB**

Create `mobile/lib/l10n/app_bg.arb` from `app_en.arb`, set `@@locale` to `bg`,
translate all message values into Bulgarian, preserve all metadata blocks,
placeholders, ICU plural variables, URLs, product names, and Nostr strings.

Use these brand rules while translating:

- prefer natural Bulgarian UI language over literal English structure
- translate "loop" in video/product contexts as "луп" when it means a short
  looping Divine video; use ordinary Bulgarian only when the source means a
  generic technical cycle
- avoid stiff phrases like "съдържание не е налично" when a warmer phrase fits
- keep safety/auth/error copy clear before playful
- keep legal/permission copy precise

- [ ] **Step 2: Wire app UI picker**

Add this entry to `LocalePreferenceService.supportedLocales`:

```dart
'bg': 'Български',
```

- [ ] **Step 3: Wire content language picker**

Add this entry to `LanguagePreferenceService.supportedLanguages`:

```dart
'bg': 'Bulgarian',
```

- [ ] **Step 4: Wire Android locale config**

Add this entry to `mobile/android/app/src/main/res/xml/locales_config.xml`:

```xml
<locale android:name="bg"/>
```

- [ ] **Step 5: Wire iOS locale declarations**

Add `<string>bg</string>` to `CFBundleLocalizations` in
`mobile/ios/Runner/Info.plist`.

Add `bg,` to `knownRegions` in
`mobile/ios/Runner.xcodeproj/project.pbxproj`.

- [ ] **Step 6: Generate Flutter l10n**

Run from `mobile/`:

```bash
flutter gen-l10n
```

Expected: `lib/l10n/generated/app_localizations_bg.dart` is created and
`lib/l10n/generated/app_localizations.dart` includes `Locale('bg')`.

## Chunk 3: Verification And Review

### Task 3: Verify Bulgarian Support

**Files:**
- All files touched above.

- [ ] **Step 1: Run focused test suite**

Run from `mobile/`:

```bash
flutter test test/l10n test/services/locale_preference_service_test.dart test/services/language_preference_service_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Verify generated l10n is current**

Run from `mobile/`:

```bash
flutter gen-l10n
git diff --exit-code lib/l10n/generated
```

Expected: no generated diffs after regeneration.

- [ ] **Step 3: Review Bulgarian high-signal copy**

Manually inspect the Bulgarian translations for:

- Settings and language pickers
- Auth/account flows
- Video creation/upload/publish flows
- Empty states
- Retry/error messages
- AI/no-slop/human-made messaging
- Permissions/privacy copy

Fix any stiff, literal, or off-brand strings.

- [ ] **Step 4: Run format/analyze where relevant**

Run from `mobile/`:

```bash
dart format test/l10n/resolve_app_ui_locale_test.dart test/l10n/l10n_test.dart test/l10n/platform_locale_declarations_test.dart test/services/locale_preference_service_test.dart test/services/language_preference_service_test.dart lib/services/locale_preference_service.dart lib/services/language_preference_service.dart
flutter analyze lib/l10n lib/services test/l10n test/services/locale_preference_service_test.dart test/services/language_preference_service_test.dart
```

Expected: format completes; analyze has no new errors in touched Dart files.

- [ ] **Step 5: Commit**

Run:

```bash
git add docs/superpowers/specs/2026-05-02-bulgarian-language-support-design.md \
  docs/superpowers/plans/2026-05-02-bulgarian-language-support.md \
  mobile/lib/l10n/app_bg.arb \
  mobile/lib/l10n/generated/app_localizations.dart \
  mobile/lib/l10n/generated/app_localizations_bg.dart \
  mobile/lib/services/locale_preference_service.dart \
  mobile/lib/services/language_preference_service.dart \
  mobile/android/app/src/main/res/xml/locales_config.xml \
  mobile/ios/Runner/Info.plist \
  mobile/ios/Runner.xcodeproj/project.pbxproj \
  mobile/test/l10n/l10n_test.dart \
  mobile/test/l10n/resolve_app_ui_locale_test.dart \
  mobile/test/l10n/platform_locale_declarations_test.dart \
  mobile/test/services/locale_preference_service_test.dart \
  mobile/test/services/language_preference_service_test.dart
git commit -m "feat(l10n): add Bulgarian language support"
```
