// ABOUTME: Resolves AppLocalizations outside of a BuildContext.
// ABOUTME: Used by services constructed via Riverpod providers / factories.

import 'dart:ui';

import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns [AppLocalizations] for the user's current preferred locale,
/// or for the device default falling back through [resolveAppUiLocale].
///
/// Mirrors the locale that `MaterialApp.router` ends up using at runtime
/// (via `LocaleCubit` + `localeListResolutionCallback: resolveAppUiLocale`)
/// without requiring a [BuildContext]. Use this from services that are
/// constructed inside Riverpod factories or other context-less call sites
/// — e.g. `CollaboratorInviteService` built by `VideoPublishService`.
AppLocalizations currentAppL10n(SharedPreferences prefs) {
  final saved = prefs.getString(LocalePreferenceService.prefsKey);
  const supported = AppLocalizations.supportedLocales;
  final isSupported =
      saved != null && supported.any((locale) => locale.languageCode == saved);
  final locale = isSupported
      ? Locale(saved)
      : resolveAppUiLocale(
          PlatformDispatcher.instance.locales,
          supported,
        );
  return lookupAppLocalizations(locale);
}
