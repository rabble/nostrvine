// ABOUTME: Tests for InAppPurchaseValidator store interactions + stream bridge.
// ABOUTME: Mocks InAppPurchase via mocktail and drives the purchase stream.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';

class _MockInAppPurchase extends Mock implements InAppPurchase {}

class _FakePurchaseParam extends Fake implements PurchaseParam {}

class _FakePurchaseDetails extends Fake implements PurchaseDetails {}

PurchaseDetails _purchase(
  String productId, {
  PurchaseStatus status = PurchaseStatus.purchased,
  bool pendingComplete = false,
}) {
  return PurchaseDetails(
    productID: productId,
    status: status,
    transactionDate: '0',
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'test',
    ),
  )..pendingCompletePurchase = pendingComplete;
}

/// A minimal fake [ProductDetails] for tests.
ProductDetails _product(String id, {String price = '\$4.99'}) {
  return ProductDetails(
    id: id,
    title: 'Divine Supporter',
    description: 'Keep Divine running',
    price: price,
    rawPrice: 4.99,
    currencyCode: 'USD',
  );
}

void main() {
  late _MockInAppPurchase store;
  late InAppPurchaseValidator validator;

  setUpAll(() {
    registerFallbackValue(_FakePurchaseParam());
    registerFallbackValue(_FakePurchaseDetails());
  });

  setUp(() {
    store = _MockInAppPurchase();
    validator = InAppPurchaseValidator(
      store: store,
      productIds: const {'divine.supporter.monthly'},
    );
  });

  tearDown(() {
    validator.dispose();
  });

  group(InAppPurchaseValidator, () {
    test('isAvailable delegates to the store', () async {
      when(store.isAvailable).thenAnswer((_) async => true);
      expect(await validator.isAvailable, isTrue);

      when(store.isAvailable).thenAnswer((_) async => false);
      expect(await validator.isAvailable, isFalse);
    });

    group('fetchProducts', () {
      test('throws StoreUnavailableException when store unavailable', () async {
        when(store.isAvailable).thenAnswer((_) async => false);
        await expectLater(
          validator.fetchProducts(),
          throwsA(isA<StoreUnavailableException>()),
        );
      });

      test('maps ProductDetails to SupporterTier', () async {
        when(store.isAvailable).thenAnswer((_) async => true);
        when(() => store.queryProductDetails(any())).thenAnswer(
          (_) async => ProductDetailsResponse(
            productDetails: [_product('divine.supporter.monthly')],
            notFoundIDs: [],
          ),
        );
        final tiers = await validator.fetchProducts();
        expect(tiers, hasLength(1));
        expect(tiers.single.productId, 'divine.supporter.monthly');
        expect(tiers.single.title, 'Divine Supporter');
        expect(tiers.single.price, '\$4.99');
        expect(tiers.single.currencyCode, 'USD');
      });

      test('returns empty when no products found', () async {
        when(store.isAvailable).thenAnswer((_) async => true);
        when(() => store.queryProductDetails(any())).thenAnswer(
          (_) async => ProductDetailsResponse(
            productDetails: const [],
            notFoundIDs: ['divine.supporter.monthly'],
          ),
        );
        expect(await validator.fetchProducts(), isEmpty);
      });
    });

    group('purchase', () {
      test('throws StoreUnavailableException when store unavailable', () async {
        when(store.isAvailable).thenAnswer((_) async => false);
        await expectLater(
          validator.purchase('divine.supporter.monthly'),
          throwsA(isA<StoreUnavailableException>()),
        );
      });

      test(
        'throws PurchaseFailedException when store fails to start',
        () async {
          when(store.isAvailable).thenAnswer((_) async => true);
          when(() => store.queryProductDetails(any())).thenAnswer(
            (_) async => ProductDetailsResponse(
              productDetails: [_product('divine.supporter.monthly')],
              notFoundIDs: const [],
            ),
          );
          when(
            () => store.buyNonConsumable(
              purchaseParam: any(named: 'purchaseParam'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => store.purchaseStream,
          ).thenAnswer((_) => const Stream<List<PurchaseDetails>>.empty());
          await expectLater(
            validator.purchase('divine.supporter.monthly'),
            throwsA(isA<PurchaseFailedException>()),
          );
        },
      );
    });

    group('purchase stream outcomes', () {
      late StreamController<List<PurchaseDetails>> streamController;

      setUp(() {
        // Broadcast so the validator's subscription and the test can both listen.
        streamController = StreamController<List<PurchaseDetails>>.broadcast();
        when(store.isAvailable).thenAnswer((_) async => true);
        when(
          () => store.purchaseStream,
        ).thenAnswer((_) => streamController.stream);
        when(() => store.queryProductDetails(any())).thenAnswer(
          (_) async => ProductDetailsResponse(
            productDetails: [_product('divine.supporter.monthly')],
            notFoundIDs: const [],
          ),
        );
        when(
          () => store.buyNonConsumable(
            purchaseParam: any(named: 'purchaseParam'),
          ),
        ).thenAnswer((_) async => true);
        when(() => store.completePurchase(any())).thenAnswer((_) async {});
      });

      tearDown(() => streamController.close());

      // Flushes pending microtasks so purchase() finishes its internal awaits
      // (queryProductDetails + buyNonConsumable) before we inject a stream event.
      Future<void> pumpMicrotasks({int iterations = 5}) async {
        for (var i = 0; i < iterations; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      test(
        'startListening receives purchases before a purchase call',
        () async {
          validator.startListening();
          final emitted = validator.entitlementChanges.first;
          streamController.add([_purchase('divine.supporter.monthly')]);

          expect((await emitted).isSupporter, isTrue);
        },
      );

      test(
        'purchase future completes with a typed failure when the stream errors',
        () async {
          final future = validator.purchase('divine.supporter.monthly');
          await pumpMicrotasks();
          streamController.addError(StateError('store stream failed'));

          await expectLater(future, throwsA(isA<PurchaseFailedException>()));
        },
      );

      test(
        'purchased status resolves active entitlement and completes purchase',
        () async {
          final future = validator.purchase('divine.supporter.monthly');
          await pumpMicrotasks();
          streamController.add([
            _purchase(
              'divine.supporter.monthly',
              status: PurchaseStatus.purchased,
              pendingComplete: true,
            ),
          ]);
          final result = await future.timeout(const Duration(seconds: 1));
          expect(result.isActive, isTrue);
          expect(result.productId, 'divine.supporter.monthly');
          expect(result.isSupporter, isTrue);
          verify(() => store.completePurchase(any())).called(1);
        },
      );

      test('restored status resolves active entitlement', () async {
        final future = validator.purchase('divine.supporter.monthly');
        await pumpMicrotasks();
        streamController.add([
          _purchase(
            'divine.supporter.monthly',
            status: PurchaseStatus.restored,
          ),
        ]);
        final result = await future.timeout(const Duration(seconds: 1));
        expect(result.isActive, isTrue);
      });

      test('error status rejects with PurchaseFailedException', () async {
        final future = validator.purchase('divine.supporter.monthly');
        await pumpMicrotasks();
        streamController.add([
          _purchase('divine.supporter.monthly', status: PurchaseStatus.error),
        ]);
        await expectLater(future, throwsA(isA<PurchaseFailedException>()));
      });

      test('canceled status rejects with PurchaseFailedException', () async {
        final future = validator.purchase('divine.supporter.monthly');
        await pumpMicrotasks();
        streamController.add([
          _purchase(
            'divine.supporter.monthly',
            status: PurchaseStatus.canceled,
          ),
        ]);
        await expectLater(future, throwsA(isA<PurchaseFailedException>()));
      });

      test(
        'pending status keeps the purchase unresolved until purchased',
        () async {
          final future = validator.purchase('divine.supporter.monthly');
          await pumpMicrotasks();
          streamController.add([
            _purchase(
              'divine.supporter.monthly',
              status: PurchaseStatus.pending,
            ),
          ]);
          await pumpMicrotasks();
          // Then resolve with a purchased event.
          streamController.add([
            _purchase(
              'divine.supporter.monthly',
              status: PurchaseStatus.purchased,
            ),
          ]);
          final result = await future.timeout(const Duration(seconds: 1));
          expect(result.isSupporter, isTrue);
        },
      );

      test('pending does not clear an active entitlement', () async {
        final emitted = <SupporterEntitlement>[];
        validator.entitlementChanges.listen(emitted.add);

        final future = validator.purchase('divine.supporter.monthly');
        await pumpMicrotasks();
        streamController.add([
          _purchase('divine.supporter.monthly'),
        ]);
        await future.timeout(const Duration(seconds: 1));

        streamController.add([
          _purchase(
            'divine.supporter.monthly',
            status: PurchaseStatus.pending,
          ),
        ]);
        await pumpMicrotasks();

        expect(emitted.last.isSupporter, isTrue);
      });

      test('emits pending and confirming lifecycle states', () async {
        final emitted = <EntitlementLifecycle>[];
        validator.lifecycleChanges.listen(emitted.add);

        final future = validator.purchase('divine.supporter.monthly');
        await pumpMicrotasks();
        streamController.add([
          _purchase(
            'divine.supporter.monthly',
            status: PurchaseStatus.pending,
          ),
        ]);
        await pumpMicrotasks();
        streamController.add([
          _purchase('divine.supporter.monthly'),
        ]);
        await future.timeout(const Duration(seconds: 1));

        expect(
          emitted,
          equals([
            EntitlementLifecycle.pending,
            EntitlementLifecycle.confirming,
          ]),
        );
      });

      test('entitlementChanges emits on purchase', () async {
        final emitted = <SupporterEntitlement>[];
        validator.entitlementChanges.listen(emitted.add);
        final future = validator.purchase('divine.supporter.monthly');
        await pumpMicrotasks();
        streamController.add([
          _purchase(
            'divine.supporter.monthly',
            status: PurchaseStatus.purchased,
          ),
        ]);
        await future.timeout(const Duration(seconds: 1));
        expect(emitted, isNotEmpty);
        expect(emitted.last.isSupporter, isTrue);
      });
    });

    group('restorePurchases', () {
      test('throws StoreUnavailableException when store unavailable', () async {
        when(store.isAvailable).thenAnswer((_) async => false);
        await expectLater(
          validator.restorePurchases(),
          throwsA(isA<StoreUnavailableException>()),
        );
      });

      test(
        'resolves inactive and calls restorePurchases on the store',
        () async {
          when(store.isAvailable).thenAnswer((_) async => true);
          when(
            () => store.purchaseStream,
          ).thenAnswer((_) => const Stream<List<PurchaseDetails>>.empty());
          when(() => store.restorePurchases()).thenAnswer((_) async {});
          final result = await validator.restorePurchases();
          expect(result, equals(SupporterEntitlement.inactive));
          verify(() => store.restorePurchases()).called(1);
        },
      );
    });

    test('dispose closes the entitlement stream', () async {
      when(
        () => store.purchaseStream,
      ).thenAnswer((_) => const Stream<List<PurchaseDetails>>.empty());
      // Trigger listener subscription then dispose.
      validator.entitlementChanges.listen((_) {});
      validator.dispose();
      // Re-create to avoid tearDown double-dispose.
      validator = InAppPurchaseValidator(store: store);
    });
  });
}
