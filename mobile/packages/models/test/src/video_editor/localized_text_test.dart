import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizedText', () {
    const subject = LocalizedText({
      'en': 'Adjustable dumbbell',
      'de': 'Verstellbare Hantel',
      'ja': '調節可能なダンベル',
    });

    group('resolve', () {
      test('returns the value for the requested locale', () {
        expect(subject.resolve('de'), 'Verstellbare Hantel');
        expect(subject.resolve('ja'), '調節可能なダンベル');
      });

      test('falls back to English when the locale is missing', () {
        expect(subject.resolve('fr'), 'Adjustable dumbbell');
      });

      test('falls back to the first value when English is absent', () {
        const noEnglish = LocalizedText({'de': 'Hantel'});

        expect(noEnglish.resolve('fr'), 'Hantel');
      });

      test('returns an empty string when no values exist', () {
        const empty = LocalizedText({});

        expect(empty.resolve('en'), '');
      });
    });

    group('fallback', () {
      test('returns the English value', () {
        expect(subject.fallback, 'Adjustable dumbbell');
      });
    });

    group('single', () {
      test('stores the value under the English fallback locale', () {
        final text = LocalizedText.single('Heart');

        expect(text.values, {'en': 'Heart'});
        expect(text.resolve('de'), 'Heart');
      });
    });

    group('fromJson', () {
      test('treats a plain string as the English fallback value', () {
        final text = LocalizedText.fromJson('Heart');

        expect(text, const LocalizedText({'en': 'Heart'}));
      });

      test('maps a JSON object to per-locale values', () {
        final text = LocalizedText.fromJson(const {
          'en': 'Heart',
          'de': 'Herz',
        });

        expect(text, const LocalizedText({'en': 'Heart', 'de': 'Herz'}));
      });

      test('returns an empty LocalizedText for unsupported shapes', () {
        expect(LocalizedText.fromJson(null), const LocalizedText({}));
        expect(LocalizedText.fromJson(42), const LocalizedText({}));
      });
    });

    group('toJson', () {
      test('serializes a single English value to a plain string', () {
        expect(const LocalizedText({'en': 'Heart'}).toJson(), 'Heart');
      });

      test('serializes multiple locales to a map', () {
        const text = LocalizedText({'en': 'Heart', 'de': 'Herz'});

        expect(text.toJson(), {'en': 'Heart', 'de': 'Herz'});
      });

      test('serializes a single non-English value to a map', () {
        expect(const LocalizedText({'de': 'Herz'}).toJson(), {'de': 'Herz'});
      });
    });

    group('roundtrip', () {
      test('preserves values through fromJson/toJson', () {
        const original = LocalizedText({'en': 'Heart', 'de': 'Herz'});

        expect(LocalizedText.fromJson(original.toJson()), original);
      });

      test('preserves a single English value through fromJson/toJson', () {
        const original = LocalizedText({'en': 'Heart'});

        expect(LocalizedText.fromJson(original.toJson()), original);
      });
    });

    group('equality', () {
      test('two instances with the same values are equal', () {
        expect(
          const LocalizedText({'en': 'Heart'}),
          const LocalizedText({'en': 'Heart'}),
        );
      });

      test('instances with different values are not equal', () {
        expect(
          const LocalizedText({'en': 'Heart'}),
          isNot(const LocalizedText({'en': 'Herz'})),
        );
      });
    });
  });
}
