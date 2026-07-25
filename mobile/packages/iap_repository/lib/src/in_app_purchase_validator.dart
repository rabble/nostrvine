// ABOUTME: Client-first EntitlementValidator backed by the in_app_purchase
// ABOUTME: plugin (StoreKit on iOS, Google Play Billing on Android).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:iap_repository/src/entitlement_validator.dart';
import 'package:iap_repository/src/exceptions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:models/models.dart';

/// The store product IDs Divine treats as supporter tiers.
///
/// These must exist in App Store Connect and the Google Play Console for real
/// purchases to work. While the flag is off and these are unconfigured,
/// fetchProducts simply returns an empty list.
@visibleForTesting
const Set<String> supporterProductIds = <String>{'divine.supporter.monthly'};

/// [EntitlementValidator] backed by the `in_app_purchase` plugin.
///
/// Purchase results arrive asynchronously on [InAppPurchase.purchaseStream];
/// [purchase] bridges that into a single Future using a [Completer]. This keeps
/// the public surface Future-based while still honoring the store's delivery
/// model.
class InAppPurchaseValidator implements EntitlementValidator {
  /// Creates an [InAppPurchaseValidator].
  ///
  /// [store] is injectable for tests; production code passes
  /// [InAppPurchase.instance].
  InAppPurchaseValidator({
    InAppPurchase? store,
    @visibleForTesting Set<String>? productIds,
  }) : _store = store ?? InAppPurchase.instance,
       _productIds = productIds ?? supporterProductIds;

  final InAppPurchase _store;
  final Set<String> _productIds;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<SupporterEntitlement> _entitlementController =
      StreamController<SupporterEntitlement>.broadcast();

  /// Pending purchase listeners keyed by product id, awaiting the matching
  /// result on the purchase stream.
  final Map<String, Completer<SupporterEntitlement>> _pendingPurchases = {};

  bool _listening = false;

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _subscription = _store.purchaseStream.listen(
      _handlePurchaseStream,
      onError: _entitlementController.addError,
    );
  }

  void _handlePurchaseStream(List<PurchaseDetails> purchases) {
    purchases.forEach(_processPurchase);
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    final completer = _pendingPurchases.remove(purchase.productID);
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final entitlement = _entitlementFromPurchase(purchase);
        _entitlementController.add(entitlement);
        await _completeSafely(purchase);
        completer?.complete(entitlement);
      case PurchaseStatus.error:
        final exception = PurchaseFailedException(
          purchase.error?.code,
          purchase.error?.message ?? 'Purchase failed.',
        );
        completer?.completeError(exception);
        _entitlementController.addError(exception);
      case PurchaseStatus.canceled:
        const exception = PurchaseFailedException(
          null,
          'Purchase was cancelled.',
        );
        completer?.completeError(exception);
      case PurchaseStatus.pending:
        // Still pending parental approval / payment settlement; keep waiting
        // for the same completer on the next stream event.
        if (completer != null) {
          _pendingPurchases[purchase.productID] = completer;
        }
        _entitlementController.add(SupporterEntitlement.inactive);
    }
  }

  Future<void> _completeSafely(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _store.completePurchase(purchase);
    } on Object {
      // Swallow: completing the purchase is best-effort; the store will
      // continue to deliver it until acknowledged.
    }
  }

  SupporterEntitlement _entitlementFromPurchase(PurchaseDetails purchase) {
    final now = DateTime.now();
    return SupporterEntitlement(
      productId: purchase.productID,
      source: defaultTargetPlatform == TargetPlatform.iOS
          ? EntitlementSource.appStore
          : EntitlementSource.playStore,
      purchaseDate: now,
      // The plugin does not expose renewal/expiry dates uniformly across
      // stores; the server-side validator (later) will supply authoritative
      // expiry. We leave it null and treat active support as session-scoped
      // for the client-first MVP.
    );
  }

  @override
  Future<bool> get isAvailable => _store.isAvailable();

  @override
  Future<List<SupporterTier>> fetchProducts() async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailableException();
    }
    if (_productIds.isEmpty) return const <SupporterTier>[];
    final response = await _store.queryProductDetails(_productIds);
    return response.productDetails.map(_tierFromProduct).toList();
  }

  SupporterTier _tierFromProduct(ProductDetails product) => SupporterTier(
    productId: product.id,
    title: product.title,
    price: product.price,
    currencyCode: product.currencyCode,
    description: product.description,
  );

  @override
  Future<SupporterEntitlement> purchase(String productId) async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailableException();
    }
    _ensureListening();

    final completer = Completer<SupporterEntitlement>();
    _pendingPurchases[productId] = completer;

    final productDetails = await _store.queryProductDetails({productId});
    final product = productDetails.productDetails.isEmpty
        ? null
        : productDetails.productDetails.first;

    final initiated = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product ?? _placeholderProduct(productId),
      ),
    );
    if (!initiated) {
      _pendingPurchases.remove(productId);
      throw const PurchaseFailedException(
        null,
        'Store did not start the purchase.',
      );
    }
    return completer.future;
  }

  /// A fallback [ProductDetails] used only to satisfy [PurchaseParam] when the
  /// product was fetched by id at purchase time but the store didn't return
  /// its details. The store will reject the purchase if the id is invalid.
  ProductDetails _placeholderProduct(String productId) {
    return ProductDetails(
      id: productId,
      title: 'Divine Supporter',
      description: '',
      price: '',
      rawPrice: 0,
      currencyCode: '',
    );
  }

  @override
  Future<SupporterEntitlement> restorePurchases() async {
    if (!await _store.isAvailable()) {
      throw const StoreUnavailableException();
    }
    _ensureListening();
    await _store.restorePurchases();

    // Restored purchases are delivered on the purchase stream. We resolve to
    // inactive synchronously and rely on the stream + repository cache to
    // surface any restored entitlement, keeping restore non-blocking.
    return SupporterEntitlement.inactive;
  }

  @override
  Stream<SupporterEntitlement> get entitlementChanges =>
      _entitlementController.stream;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _listening = false;
    unawaited(_entitlementController.close());
  }
}
