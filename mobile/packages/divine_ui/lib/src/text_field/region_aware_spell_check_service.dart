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

  /// Default region per language for the app's supported locales, used to
  /// produce a candidate the platform checker is known to support.
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

  /// The region-qualified locales to try, most-preferred first: the device's
  /// own regional variant of the language, then the [fallbackRegions] default,
  /// then the bare locale as a last resort. An already-region-qualified locale
  /// is returned as the single candidate.
  @visibleForTesting
  List<Locale> localeCandidates(Locale locale) {
    if (locale.countryCode != null) return [locale];

    final candidates = <Locale>[];
    for (final device in _locales) {
      if (device.languageCode == locale.languageCode &&
          device.countryCode != null) {
        candidates.add(Locale(locale.languageCode, device.countryCode));
        break;
      }
    }

    final region = fallbackRegions[locale.languageCode];
    if (region != null) {
      final mapped = Locale(locale.languageCode, region);
      if (!candidates.contains(mapped)) candidates.add(mapped);
    }

    candidates.add(locale);
    return candidates;
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    List<SuggestionSpan>? result;
    for (final candidate in localeCandidates(locale)) {
      // A supported language returns a (possibly empty) list; an unsupported
      // one returns null. Stop at the first supported candidate.
      result = await _delegate.fetchSpellCheckSuggestions(candidate, text);
      if (result != null) return result;
    }
    return result;
  }
}
