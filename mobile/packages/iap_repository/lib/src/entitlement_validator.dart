// ABOUTME: Abstract store + entitlement surface for Divine supporters.
// ABOUTME: Implementations back this with StoreKit/Play Billing (client-first)
// ABOUTME: or, later, a server-side receipt-validation backend.

import 'package:models/models.dart';

/// Abstracts the in-app purchase store and supporter-entitlement source.
///
/// This is the single seam between the app and however supporter status is
/// verified. The client-first MVP backs it with on-device StoreKit / Play
/// Billing (see InAppPurchaseValidator). A server-side validator can implement
/// the same interface later without changing callers.
abstract class EntitlementValidator {
  /// Whether a store is available on this device/build. When false,
  /// [fetchProducts] / [purchase] / [restorePurchases] reject with a
  /// StoreUnavailableException.
  Future<bool> get isAvailable;

  /// Fetch the purchasable supporter tiers from the store.
  ///
  /// Returns an empty list when the store is available but no supporter
  /// products are configured yet.
  Future<List<SupporterTier>> fetchProducts();

  /// Begin a purchase for [productId]. Resolves with the resulting
  /// SupporterEntitlement once the store confirms the purchase.
  ///
  /// Throws StoreUnavailableException, PurchaseFailedException, or
  /// PurchasePendingException.
  Future<SupporterEntitlement> purchase(String productId);

  /// Restore previous supporter purchases tied to this store account.
  ///
  /// Resolves with the active SupporterEntitlement if one is found, or
  /// SupporterEntitlement.inactive otherwise. Throws RestoreFailedException
  /// on store errors.
  Future<SupporterEntitlement> restorePurchases();

  /// A stream of the current entitlement, emitting whenever the store reports
  /// a purchase, renewal, cancellation, or expiry. Emits
  /// [SupporterEntitlement.inactive] until a verified purchase arrives.
  Stream<SupporterEntitlement> get entitlementChanges;

  /// Release store listeners and resources.
  void dispose();
}
