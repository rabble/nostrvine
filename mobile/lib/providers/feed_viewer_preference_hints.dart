// ABOUTME: Reads viewer language/country hints used by Funnelcake feed requests.
// ABOUTME: Keeps feed providers from duplicating preference lookup behavior.

import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/locale_preference_service.dart';

const _countryHintTimeout = Duration(milliseconds: 250);

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

class FeedViewerPreferenceHints {
  const FeedViewerPreferenceHints({
    required this.preferredLanguages,
    required this.viewerCountry,
  });

  final List<String> preferredLanguages;
  final String? viewerCountry;
}

List<String> buildPreferredFeedLanguages({
  required String contentLanguage,
  String? appLocale,
  Iterable<Locale> deviceLocales = const [],
}) {
  final languages = <String>[];
  final seen = <String>{};

  void addLanguage(String? rawLanguage) {
    final normalized = _normalizeLanguageHint(rawLanguage);
    if (normalized == null || !seen.add(normalized)) {
      return;
    }
    languages.add(normalized);
  }

  addLanguage(contentLanguage);
  addLanguage(appLocale);
  for (final locale in deviceLocales) {
    addLanguage(locale.languageCode);
  }

  return languages;
}

Future<FeedViewerPreferenceHints> readFeedViewerPreferenceHints(
  ProviderReader read,
) async {
  final languagePreferenceService = read(languagePreferenceServiceProvider);
  await languagePreferenceService.initialize();
  final contentLanguage = languagePreferenceService.contentLanguage.trim();
  final preferredLanguages = buildPreferredFeedLanguages(
    contentLanguage: contentLanguage,
    appLocale: _readAppLocale(read),
    deviceLocales: PlatformDispatcher.instance.locales,
  );

  String? viewerCountry;
  try {
    final geoInfo = await read(
      geoBlockingServiceProvider,
    ).getGeoInfo().timeout(_countryHintTimeout);
    final country = geoInfo.country.trim();
    if (country.isNotEmpty && country.toUpperCase() != 'UNKNOWN') {
      viewerCountry = country;
    }
  } on Object {
    viewerCountry = null;
  }

  return FeedViewerPreferenceHints(
    preferredLanguages: preferredLanguages,
    viewerCountry: viewerCountry,
  );
}

String? _readAppLocale(ProviderReader read) {
  try {
    return read(sharedPreferencesProvider).getString(
      LocalePreferenceService.prefsKey,
    );
  } on Object {
    return null;
  }
}

String? _normalizeLanguageHint(String? rawLanguage) {
  final trimmed = rawLanguage?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final baseLanguage = trimmed
      .replaceAll('_', '-')
      .split('-')
      .first
      .toLowerCase();
  return baseLanguage.isEmpty ? null : baseLanguage;
}
