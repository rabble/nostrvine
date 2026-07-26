// ABOUTME: No-op EntitlementValidator for unsupported platforms (web).
// ABOUTME: Always reports no store and an inactive entitlement.

import 'dart:async';

import 'package:iap_repository/src/entitlement_validator.dart';
import 'package:iap_repository/src/exceptions.dart';
import 'package:models/models.dart';

/// EntitlementValidator that reports no store availability.
///
/// Used on platforms without an in-app purchase store (e.g. web) so the rest of
/// the app can treat the supporter feature uniformly.
class StubEntitlementValidator implements EntitlementValidator {
  final StreamController<SupporterEntitlement> _controller =
      StreamController<SupporterEntitlement>.broadcast();

  @override
  void startListening() {}

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<List<SupporterTier>> fetchProducts() =>
      Future.value(const <SupporterTier>[]);

  @override
  Future<SupporterEntitlement> purchase(
    String productId, {
    String? capturedPubkey,
    String? attemptId,
  }) => Future.error(const StoreUnavailableException());

  @override
  Future<SupporterEntitlement> restorePurchases({
    String? capturedPubkey,
    String? attemptId,
  }) => Future.value(SupporterEntitlement.inactive);

  @override
  Stream<SupporterEntitlement> get entitlementChanges => _controller.stream;

  @override
  Stream<EntitlementLifecycle> get lifecycleChanges => const Stream.empty();

  @override
  Stream<SupporterPurchaseProof> get purchaseProofChanges =>
      const Stream.empty();

  @override
  Future<void> completePurchase(SupporterPurchaseProof proof) async {}

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}
