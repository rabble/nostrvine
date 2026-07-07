import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A [SpellCheckService] that guarantees the locale handed to the platform
/// spell checker carries a country/region code the checker actually supports.
///
/// iOS' `UITextChecker` only recognises specific region-qualified languages —
/// it has `en_US`/`en_GB` but neither bare `en` nor uncommon regions like
/// `en_CH` — and returns `null` (no spell check at all) for anything it does
/// not know. The app resolves UI locales without a region (`en`, `de`, …), and
/// a device in an unsupported region (e.g. Switzerland) would otherwise pick a
/// language variant the checker rejects. This service tries a prioritized list
/// of region-qualified candidates and uses the first the platform accepts.
class RegionAwareSpellCheckService implements SpellCheckService {
  /// Creates a region-aware spell check service.
  ///
  /// [delegate] performs the actual platform lookup and defaults to
  /// [DefaultSpellCheckService]. [deviceLocales] overrides the source of the
  /// device's preferred locales (defaults to [PlatformDispatcher.locales]);
  /// both parameters exist for testing.
  RegionAwareSpellCheckService({
    SpellCheckService? delegate,
    List<Locale>? deviceLocales,
  }) : _delegate = delegate ?? DefaultSpellCheckService(),
       _deviceLocales = deviceLocales;

  final SpellCheckService _delegate;
  final List<Locale>? _deviceLocales;

  /// Default region per language for locales with platform spell-check support,
  /// used to produce a candidate the platform checker is known to support.
  static const Map<String, String> fallbackRegions = {
    'ar': 'SA',
    'bg': 'BG',
    'de': 'DE',
    'en': 'US',
    'es': 'ES',
    'fr': 'FR',
    'id': 'ID',
    'it': 'IT',
    'ja': 'JP',
    'ko': 'KR',
    'nl': 'NL',
    'pl': 'PL',
    'pt': 'BR',
    'ro': 'RO',
    'sv': 'SE',
    'tr': 'TR',
  };

  List<Locale> get _locales =>
      _deviceLocales ?? PlatformDispatcher.instance.locales;

  final Map<String, Locale> _resolvedLocaleCache = {};

  /// The locales to try, most-preferred first: the locale's own region (when it
  /// already carries one), then the device's regional variant of the language,
  /// then the [fallbackRegions] default, then the bare locale as a last resort.
  /// Duplicates are dropped while preserving that order.
  ///
  /// A region-qualified input is tried first but still falls back, so an
  /// unsupported region (e.g. `en_VN`) resolves to a supported one instead of
  /// disabling spell check outright.
  @visibleForTesting
  List<Locale> localeCandidates(Locale locale) {
    final candidates = <Locale>[];
    void add(Locale candidate) {
      if (!candidates.contains(candidate)) candidates.add(candidate);
    }

    if (locale.countryCode != null) add(locale);

    for (final device in _locales) {
      if (device.languageCode == locale.languageCode &&
          device.countryCode != null) {
        add(Locale(locale.languageCode, device.countryCode));
        break;
      }
    }

    final region = fallbackRegions[locale.languageCode];
    if (region != null) add(Locale(locale.languageCode, region));

    add(Locale(locale.languageCode));
    return candidates;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    final candidates = localeCandidates(locale);
    final cacheKey = _cacheKeyFor(candidates);
    final cachedLocale = _resolvedLocaleCache[cacheKey];
    if (cachedLocale != null) {
      final result = await _delegate.fetchSpellCheckSuggestions(
        cachedLocale,
        text,
      );
      if (result != null) return result;
      _resolvedLocaleCache.remove(cacheKey);
    }

    List<SuggestionSpan>? result;
    for (final candidate in candidates) {
      // A supported language returns a (possibly empty) list; an unsupported
      // one returns null. Stop at the first supported candidate.
      result = await _delegate.fetchSpellCheckSuggestions(candidate, text);
      if (result != null) {
        _resolvedLocaleCache[cacheKey] = candidate;
        return result;
      }
    }
    return result;
  }

  String _cacheKeyFor(List<Locale> candidates) =>
      candidates.map((locale) => locale.toLanguageTag()).join('|');
}
