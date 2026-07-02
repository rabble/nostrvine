import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('MonetizationLink', () {
    test('parses valid kind 0 metadata and ignores invalid entries', () {
      final links = parseMonetizationLinks([
        {
          'provider': 'venmo',
          'category': 'tip',
          'url': 'https://venmo.com/u/alice',
          'enabled': true,
        },
        {
          'provider': 'venmo',
          'category': 'tip',
          'url': 'https://example.com/alice',
          'enabled': true,
        },
        {'provider': 'unknown', 'url': 'https://example.com'},
      ]);

      expect(links, hasLength(1));
      expect(links.single.provider, MonetizationLinkProvider.venmo);
      expect(links.single.enabled, isTrue);
    });

    test('normalizes provider handles to outbound urls', () {
      final result = normalizeMonetizationLinkInput(
        provider: MonetizationLinkProvider.cashApp,
        input: r'$alice',
        enabled: true,
      );

      expect(result, isA<MonetizationLinkInputValid>());
      final link = (result as MonetizationLinkInputValid).link;
      expect(link.url, r'https://cash.app/$alice');
      expect(link.category, MonetizationLinkCategory.tip);
    });

    test('rejects wrong provider domains', () {
      final result = normalizeMonetizationLinkInput(
        provider: MonetizationLinkProvider.patreon,
        input: 'https://medium.com/@alice',
        enabled: true,
      );

      expect(result, isA<MonetizationLinkInputInvalid>());
      expect(
        (result as MonetizationLinkInputInvalid).reason,
        MonetizationLinkInputInvalidReason.wrongProvider,
      );
    });

    test('rejects http provider urls', () {
      final result = normalizeMonetizationLinkInput(
        provider: MonetizationLinkProvider.venmo,
        input: 'http://venmo.com/u/alice',
        enabled: true,
      );

      expect(result, isA<MonetizationLinkInputInvalid>());
      expect(
        (result as MonetizationLinkInputInvalid).reason,
        MonetizationLinkInputInvalidReason.invalidFormat,
      );
    });

    test('ignores http provider urls parsed from kind 0 metadata', () {
      final links = parseMonetizationLinks([
        {
          'provider': 'venmo',
          'category': 'tip',
          'url': 'http://venmo.com/u/alice',
          'enabled': true,
        },
      ]);

      expect(links, isEmpty);
    });

    test('deduplicates encoded links by provider in provider order', () {
      final encoded = encodeMonetizationLinks([
        const MonetizationLink(
          provider: MonetizationLinkProvider.venmo,
          category: MonetizationLinkCategory.tip,
          url: 'https://venmo.com/u/old',
          enabled: true,
        ),
        const MonetizationLink(
          provider: MonetizationLinkProvider.cashApp,
          category: MonetizationLinkCategory.tip,
          url: r'https://cash.app/$alice',
          enabled: false,
        ),
        const MonetizationLink(
          provider: MonetizationLinkProvider.venmo,
          category: MonetizationLinkCategory.tip,
          url: 'https://venmo.com/u/new',
          enabled: false,
        ),
      ]);

      expect(encoded.map((item) => item['provider']), ['cash_app', 'venmo']);
      expect(encoded.last['url'], 'https://venmo.com/u/new');
      expect(encoded.last['enabled'], isFalse);
    });
  });
}
