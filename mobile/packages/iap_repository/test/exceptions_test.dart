// ABOUTME: Tests for the EntitlementException hierarchy and StubEntitlementValidator.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';

void main() {
  group(EntitlementException, () {
    test('StoreUnavailableException has stable kind', () {
      const exception = StoreUnavailableException();
      expect(exception.kind, 'StoreUnavailableException');
      expect(exception.toString(), contains('StoreUnavailableException'));
    });

    test('PurchaseFailedException carries responseCode', () {
      const exception = PurchaseFailedException('user_canceled', 'cancelled');
      expect(exception.responseCode, 'user_canceled');
      expect(exception.message, 'cancelled');
    });

    test('PurchaseFailedException tolerates null responseCode', () {
      const exception = PurchaseFailedException(null, 'failed');
      expect(exception.responseCode, isNull);
    });

    test('PurchasePendingException default message', () {
      const exception = PurchasePendingException();
      expect(exception.kind, 'PurchasePendingException');
      expect(exception.message, isNotEmpty);
    });

    test('RestoreFailedException default message', () {
      const exception = RestoreFailedException();
      expect(exception.kind, 'RestoreFailedException');
    });

    test('all subtypes are EntitlementException', () {
      expect(const StoreUnavailableException(), isA<EntitlementException>());
      expect(
        const PurchaseFailedException(null, 'x'),
        isA<EntitlementException>(),
      );
      expect(
        const PurchasePendingException(),
        isA<EntitlementException>(),
      );
      expect(const RestoreFailedException(), isA<EntitlementException>());
    });
  });

  group(StubEntitlementValidator, () {
    late StubEntitlementValidator validator;

    setUp(() {
      validator = StubEntitlementValidator();
    });

    tearDown(() {
      validator.dispose();
    });

    test('isAvailable is false', () async {
      expect(await validator.isAvailable, isFalse);
    });

    test('fetchProducts returns empty list', () async {
      expect(await validator.fetchProducts(), isEmpty);
    });

    test('purchase rejects with StoreUnavailableException', () async {
      await expectLater(
        validator.purchase('p'),
        throwsA(isA<StoreUnavailableException>()),
      );
    });

    test('restorePurchases resolves to inactive', () async {
      final result = await validator.restorePurchases();
      expect(result, equals(SupporterEntitlement.inactive));
      expect(result.isSupporter, isFalse);
    });

    test('entitlementChanges is a broadcast stream', () {
      expect(validator.entitlementChanges, isA<Stream<SupporterEntitlement>>());
      // Listening twice (broadcast) does not throw.
      validator.entitlementChanges.listen((_) {});
      validator.entitlementChanges.listen((_) {});
    });
  });
}
