// ABOUTME: Typed model representing a user's current supporter entitlement.
// ABOUTME: Tracks purchase state and expiry for client-side validation.

import 'package:meta/meta.dart';

/// The platform that granted the entitlement.
enum EntitlementSource {
  /// Granted by StoreKit (iOS).
  appStore,

  /// Granted by Google Play Billing (Android).
  playStore,

  /// Granted by a server-side validation backend.
  server,

  /// No entitlement / unsupported platform.
  none;

  static EntitlementSource fromValue(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'app_store':
      case 'appstore':
        return EntitlementSource.appStore;
      case 'play_store':
      case 'playstore':
        return EntitlementSource.playStore;
      case 'server':
        return EntitlementSource.server;
      default:
        return EntitlementSource.none;
    }
  }

  String get value {
    switch (this) {
      case EntitlementSource.appStore:
        return 'app_store';
      case EntitlementSource.playStore:
        return 'play_store';
      case EntitlementSource.server:
        return 'server';
      case EntitlementSource.none:
        return 'none';
    }
  }
}

/// Represents a user's supporter status at a point in time.
///
/// This is the single source of truth surfaced to the UI. For the client-first
/// MVP it is derived from on-device purchase verification; the shape is
/// designed so a server-side [EntitlementSource.server] can replace the source
/// without changing consumers.
@immutable
class SupporterEntitlement {
  const SupporterEntitlement({
    required this.productId,
    required this.source,
    this.purchaseDate,
    this.expirationDate,
    this.isActive = true,
  });

  factory SupporterEntitlement.fromJson(Map<String, dynamic> json) {
    final rawPurchase = json['purchaseDate'];
    final rawExpiration = json['expirationDate'];
    return SupporterEntitlement(
      productId: json['productId'] as String? ?? '',
      source: EntitlementSource.fromValue(json['source']),
      purchaseDate: rawPurchase is String
          ? DateTime.tryParse(rawPurchase)
          : null,
      expirationDate: rawExpiration is String
          ? DateTime.tryParse(rawExpiration)
          : null,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  /// Product identifier (SKU) of the active subscription, or '' when inactive.
  final String productId;

  /// Where this entitlement was verified.
  final EntitlementSource source;

  /// When the purchase was confirmed, or null when never purchased.
  final DateTime? purchaseDate;

  /// When the subscription expires/renews, or null for one-time or unknown.
  final DateTime? expirationDate;

  /// Whether the entitlement is currently in force (verified and not expired).
  final bool isActive;

  /// True when the entitlement has an expiry date that has passed.
  bool get isExpired =>
      expirationDate != null && DateTime.now().isAfter(expirationDate!);

  /// True when this represents active, non-expired support.
  bool get isSupporter => isActive && !isExpired;

  SupporterEntitlement copyWith({
    String? productId,
    EntitlementSource? source,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    bool? isActive,
  }) => SupporterEntitlement(
    productId: productId ?? this.productId,
    source: source ?? this.source,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    expirationDate: expirationDate ?? this.expirationDate,
    isActive: isActive ?? this.isActive,
  );

  /// A copy with [isActive] recomputed against the current clock. Used when
  /// hydrating a cached entitlement on app launch.
  SupporterEntitlement refreshed() => copyWith(
    isActive: isActive && !isExpired,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'source': source.value,
    if (purchaseDate != null) 'purchaseDate': purchaseDate!.toIso8601String(),
    if (expirationDate != null)
      'expirationDate': expirationDate!.toIso8601String(),
    'isActive': isActive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupporterEntitlement &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          source == other.source &&
          purchaseDate == other.purchaseDate &&
          expirationDate == other.expirationDate &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
    productId,
    source,
    purchaseDate,
    expirationDate,
    isActive,
  );

  /// An entitlement representing no active support.
  static const SupporterEntitlement inactive = SupporterEntitlement(
    productId: '',
    source: EntitlementSource.none,
    isActive: false,
  );

  @override
  String toString() =>
      'SupporterEntitlement(productId: $productId, source: $source, '
      'isActive: $isActive, isSupporter: $isSupporter)';
}
