// ABOUTME: Tests for SupporterTier and SupporterEntitlement models.
// ABOUTME: Covers equality, JSON round-trip, expiry semantics, and inactive.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group(SupporterTier, () {
    test('toJson includes optional fields when present', () {
      const tier = SupporterTier(
        productId: 'divine.supporter.monthly',
        title: 'Divine Supporter',
        price: r'$4.99',
        currencyCode: 'USD',
        description: 'Keep Divine running',
      );
      final json = tier.toJson();
      expect(json['productId'], 'divine.supporter.monthly');
      expect(json['price'], r'$4.99');
      expect(json['currencyCode'], 'USD');
      expect(json['description'], 'Keep Divine running');
    });

    test('toJson omits null optional fields', () {
      const tier = SupporterTier(
        productId: 'p',
        title: 't',
        price: '1',
      );
      final json = tier.toJson();
      expect(json.containsKey('currencyCode'), isFalse);
      expect(json.containsKey('description'), isFalse);
    });

    test('equality and hashCode are value-based', () {
      const a = SupporterTier(
        productId: 'p',
        title: 't',
        price: '1',
        currencyCode: 'USD',
      );
      const b = SupporterTier(
        productId: 'p',
        title: 't',
        price: '1',
        currencyCode: 'USD',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group(SupporterEntitlement, () {
    test('inactive is not a supporter', () {
      expect(SupporterEntitlement.inactive.isSupporter, isFalse);
      expect(SupporterEntitlement.inactive.isActive, isFalse);
      expect(SupporterEntitlement.inactive.productId, isEmpty);
    });

    test('isSupporter true when active and not expired', () {
      final e = SupporterEntitlement(
        productId: 'p',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2026, 7, 15),
        expirationDate: DateTime.utc(2030, 7, 15),
      );
      expect(e.isActive, isTrue);
      expect(e.isExpired, isFalse);
      expect(e.isSupporter, isTrue);
    });

    test('isExpired true when expirationDate in the past', () {
      final e = SupporterEntitlement(
        productId: 'p',
        source: EntitlementSource.playStore,
        expirationDate: DateTime.utc(2000, 7, 15),
      );
      expect(e.isExpired, isTrue);
      expect(e.isSupporter, isFalse);
    });

    test('isSupporter false when explicitly inactive', () {
      const e = SupporterEntitlement(
        productId: 'p',
        source: EntitlementSource.appStore,
        isActive: false,
      );
      expect(e.isSupporter, isFalse);
    });

    test('refreshed flips isActive to false when expired', () {
      final expired = SupporterEntitlement(
        productId: 'p',
        source: EntitlementSource.appStore,
        expirationDate: DateTime.utc(2000, 7, 15),
      );
      expect(expired.refreshed().isActive, isFalse);
    });

    test('fromJson/toJson round trip', () {
      final original = SupporterEntitlement(
        productId: 'divine.supporter.monthly',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2026, 7, 23),
        expirationDate: DateTime.utc(2026, 8, 23),
      );
      final decoded = SupporterEntitlement.fromJson(original.toJson());
      expect(decoded.productId, original.productId);
      expect(decoded.source, original.source);
      expect(decoded.isActive, original.isActive);
      expect(decoded.purchaseDate, original.purchaseDate);
      expect(decoded.expirationDate, original.expirationDate);
    });

    test('fromJson tolerates missing fields', () {
      final decoded = SupporterEntitlement.fromJson(const <String, dynamic>{});
      expect(decoded.productId, isEmpty);
      expect(decoded.source, EntitlementSource.none);
      expect(decoded.isActive, isFalse);
    });

    test('EntitlementSource.fromValue parses variants', () {
      expect(
        EntitlementSource.fromValue('app_store'),
        EntitlementSource.appStore,
      );
      expect(
        EntitlementSource.fromValue('play_store'),
        EntitlementSource.playStore,
      );
      expect(EntitlementSource.fromValue('server'), EntitlementSource.server);
      expect(EntitlementSource.fromValue(null), EntitlementSource.none);
      expect(EntitlementSource.fromValue('bogus'), EntitlementSource.none);
    });

    test('equality and hashCode are value-based', () {
      final a = SupporterEntitlement(
        productId: 'p',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2026, 7, 15),
      );
      final b = SupporterEntitlement(
        productId: 'p',
        source: EntitlementSource.appStore,
        purchaseDate: DateTime.utc(2026, 7, 15),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
