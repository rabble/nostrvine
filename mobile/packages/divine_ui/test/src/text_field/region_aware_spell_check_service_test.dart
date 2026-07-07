import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSpellCheckService implements SpellCheckService {
  _FakeSpellCheckService(this._responder);

  final Future<List<SuggestionSpan>?> Function(Locale locale, String text)
  _responder;

  final List<Locale> calls = [];

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) {
    calls.add(locale);
    return _responder(locale, text);
  }
}

void main() {
  group(RegionAwareSpellCheckService, () {
    group('localeCandidates', () {
      test('tries an already-region-qualified locale first, then falls '
          'back', () {
        final service = RegionAwareSpellCheckService(deviceLocales: const []);

        expect(service.localeCandidates(const Locale('en', 'GB')), const [
          Locale('en', 'GB'),
          Locale('en', 'US'),
          Locale('en'),
        ]);
      });

      test('prefers device region, then fallback, then the bare locale', () {
        final service = RegionAwareSpellCheckService(
          deviceLocales: const [Locale('en', 'CH')],
        );

        expect(service.localeCandidates(const Locale('en')), const [
          Locale('en', 'CH'),
          Locale('en', 'US'),
          Locale('en'),
        ]);
      });

      test('ignores a device locale without a country code', () {
        final service = RegionAwareSpellCheckService(
          deviceLocales: const [Locale('en')],
        );

        expect(service.localeCandidates(const Locale('en')), const [
          Locale('en', 'US'),
          Locale('en'),
        ]);
      });

      test('does not duplicate when device region equals the fallback', () {
        final service = RegionAwareSpellCheckService(
          deviceLocales: const [Locale('en', 'US')],
        );

        expect(service.localeCandidates(const Locale('en')), const [
          Locale('en', 'US'),
          Locale('en'),
        ]);
      });

      test('falls back to just the bare locale when no region is known', () {
        final service = RegionAwareSpellCheckService(deviceLocales: const []);

        expect(service.localeCandidates(const Locale('am')), const [
          Locale('am'),
        ]);
      });

      test('uses the platform locales by default', () {
        final service = RegionAwareSpellCheckService();

        // The test binding reports an en-US platform locale; the first
        // candidate resolves the region to US either way.
        expect(
          service.localeCandidates(const Locale('en')).first.countryCode,
          'US',
        );
      });
    });

    group('fetchSpellCheckSuggestions', () {
      test('returns the first candidate the platform supports', () async {
        const span = SuggestionSpan(TextRange(start: 0, end: 3), ['The']);
        final delegate = _FakeSpellCheckService(
          (locale, _) async =>
              locale == const Locale('en', 'US') ? const [span] : null,
        );
        final service = RegionAwareSpellCheckService(
          delegate: delegate,
          deviceLocales: const [Locale('en', 'CH')],
        );

        final result = await service.fetchSpellCheckSuggestions(
          const Locale('en'),
          'Teh',
        );

        expect(delegate.calls, const [Locale('en', 'CH'), Locale('en', 'US')]);
        expect(result, const [span]);
      });

      test('falls back when the incoming locale has an unsupported '
          'region', () async {
        const span = SuggestionSpan(TextRange(start: 0, end: 3), ['The']);
        final delegate = _FakeSpellCheckService(
          (locale, _) async =>
              locale == const Locale('en', 'US') ? const [span] : null,
        );
        final service = RegionAwareSpellCheckService(
          delegate: delegate,
          deviceLocales: const [],
        );

        final result = await service.fetchSpellCheckSuggestions(
          const Locale('en', 'VN'),
          'Teh',
        );

        expect(delegate.calls, const [Locale('en', 'VN'), Locale('en', 'US')]);
        expect(result, const [span]);
      });

      test(
        'caches the first supported locale for the same candidate list',
        () async {
          const span = SuggestionSpan(TextRange(start: 0, end: 3), ['The']);
          final delegate = _FakeSpellCheckService(
            (locale, _) async =>
                locale == const Locale('en', 'US') ? const [span] : null,
          );
          final service = RegionAwareSpellCheckService(
            delegate: delegate,
            deviceLocales: const [Locale('en', 'VN')],
          );

          await service.fetchSpellCheckSuggestions(const Locale('en'), 'Teh');
          expect(delegate.calls, const [
            Locale('en', 'VN'),
            Locale('en', 'US'),
          ]);

          delegate.calls.clear();
          final result = await service.fetchSpellCheckSuggestions(
            const Locale('en'),
            'Helo',
          );

          expect(delegate.calls, const [Locale('en', 'US')]);
          expect(result, const [span]);
        },
      );

      test('re-resolves when the candidate list changes', () async {
        const span = SuggestionSpan(TextRange(start: 0, end: 3), ['The']);
        final deviceLocales = [const Locale('en', 'VN')];
        final delegate = _FakeSpellCheckService((locale, _) async {
          return switch (locale) {
            Locale(languageCode: 'en', countryCode: 'GB') => const [span],
            Locale(languageCode: 'en', countryCode: 'US') => const [span],
            _ => null,
          };
        });
        final service = RegionAwareSpellCheckService(
          delegate: delegate,
          deviceLocales: deviceLocales,
        );

        await service.fetchSpellCheckSuggestions(const Locale('en'), 'Teh');
        expect(delegate.calls, const [Locale('en', 'VN'), Locale('en', 'US')]);

        delegate.calls.clear();
        deviceLocales[0] = const Locale('en', 'GB');
        final result = await service.fetchSpellCheckSuggestions(
          const Locale('en'),
          'Helo',
        );

        expect(delegate.calls, const [Locale('en', 'GB')]);
        expect(result, const [span]);
      });

      test(
        'drops the cached locale when it stops returning suggestions',
        () async {
          const span = SuggestionSpan(TextRange(start: 0, end: 3), ['The']);
          var supportsFallbackRegion = true;
          final delegate = _FakeSpellCheckService((locale, _) async {
            if (locale == const Locale('en', 'US') && supportsFallbackRegion) {
              return const [span];
            }
            if (locale == const Locale('en')) return const [span];
            return null;
          });
          final service = RegionAwareSpellCheckService(
            delegate: delegate,
            deviceLocales: const [Locale('en', 'VN')],
          );

          await service.fetchSpellCheckSuggestions(const Locale('en'), 'Teh');
          expect(delegate.calls, const [
            Locale('en', 'VN'),
            Locale('en', 'US'),
          ]);

          delegate.calls.clear();
          supportsFallbackRegion = false;
          final result = await service.fetchSpellCheckSuggestions(
            const Locale('en'),
            'Helo',
          );

          expect(delegate.calls, const [
            Locale('en', 'US'),
            Locale('en', 'VN'),
            Locale('en', 'US'),
            Locale('en'),
          ]);
          expect(result, const [span]);
        },
      );

      test(
        'stops at a supported language that reports no misspellings',
        () async {
          final delegate = _FakeSpellCheckService((_, _) async => const []);
          final service = RegionAwareSpellCheckService(
            delegate: delegate,
            deviceLocales: const [],
          );

          final result = await service.fetchSpellCheckSuggestions(
            const Locale('en'),
            'hello',
          );

          expect(delegate.calls, const [Locale('en', 'US')]);
          expect(result, isEmpty);
        },
      );

      test('returns null when no candidate is supported', () async {
        final delegate = _FakeSpellCheckService((_, _) async => null);
        final service = RegionAwareSpellCheckService(
          delegate: delegate,
          deviceLocales: const [],
        );

        final result = await service.fetchSpellCheckSuggestions(
          const Locale('en'),
          'Teh',
        );

        expect(delegate.calls, const [Locale('en', 'US'), Locale('en')]);
        expect(result, isNull);
      });
    });
  });
}
