// ABOUTME: Typed model describing a Divine supporter subscription tier.
// ABOUTME: Maps an in-app purchase product to a human-readable support offer.

import 'package:meta/meta.dart';

/// A purchasable supporter tier, backed by a StoreKit / Play Billing product.
///
/// The [productId] is the platform-specific SKU configured in App Store
/// Connect and the Google Play Console. [price] and [currencyCode] come from
/// the store's localized price for that product so we never hard-code amounts.
@immutable
class SupporterTier {
  const SupporterTier({
    required this.productId,
    required this.title,
    required this.price,
    this.currencyCode,
    this.description,
  });

  /// Platform-specific product identifier (SKU) from the store console.
  final String productId;

  /// Human-readable title shown to the user (from the store product).
  final String title;

  /// Localized display price as returned by the store (e.g. "$4.99").
  final String price;

  /// ISO 4217 currency code for the localized price, when known.
  final String? currencyCode;

  /// Optional marketing description of the tier.
  final String? description;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'title': title,
    'price': price,
    if (currencyCode != null) 'currencyCode': currencyCode,
    if (description != null) 'description': description,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupporterTier &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          title == other.title &&
          price == other.price &&
          currencyCode == other.currencyCode &&
          description == other.description;

  @override
  int get hashCode =>
      Object.hash(productId, title, price, currencyCode, description);

  @override
  String toString() =>
      'SupporterTier(productId: $productId, title: $title, price: $price)';
}
