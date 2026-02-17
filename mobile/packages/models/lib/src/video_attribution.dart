// ABOUTME: Data models for video attribution (collaborators and Inspired By)
// ABOUTME: InspiredByInfo captures NIP-33 'a' tag references to addressable
// ABOUTME: video events (Kind 34236)

import 'package:meta/meta.dart';

/// Information about a video that inspired the current video.
///
/// Captures a NIP-33/NIP-10 `a` tag reference to an addressable event:
/// ```dart
/// ['a', '34236:<pubkey>:<d-tag>', 'wss://relay.divine.video', 'mention']
/// ```
@immutable
class InspiredByInfo {
  /// Creates an [InspiredByInfo] from an addressable event identifier.
  ///
  /// The [addressableId] must be in the format `34236:<pubkey>:<dTag>`.
  const InspiredByInfo({
    required this.addressableId,
    this.relayUrl,
  });

  /// Creates an [InspiredByInfo] from its JSON representation.
  factory InspiredByInfo.fromJson(Map<String, dynamic> json) => InspiredByInfo(
    addressableId: json['addressableId'] as String,
    relayUrl: json['relayUrl'] as String?,
  );

  /// The addressable event identifier in format `34236:<pubkey>:<dTag>`.
  final String addressableId;

  /// Optional relay URL hint for fetching the referenced event.
  final String? relayUrl;

  /// The pubkey of the creator whose video inspired this one.
  ///
  /// Extracted from [addressableId] (second segment after splitting by ':').
  String get creatorPubkey {
    final parts = addressableId.split(':');
    return parts.length > 1 ? parts[1] : '';
  }

  /// The `d` tag of the referenced video event.
  ///
  /// Extracted from [addressableId] (third segment after splitting by ':').
  String get dTag {
    final parts = addressableId.split(':');
    return parts.length > 2 ? parts[2] : '';
  }

  /// Serializes this [InspiredByInfo] to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'addressableId': addressableId,
    if (relayUrl != null) 'relayUrl': relayUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InspiredByInfo &&
          runtimeType == other.runtimeType &&
          addressableId == other.addressableId;

  @override
  int get hashCode => addressableId.hashCode;

  @override
  String toString() => 'InspiredByInfo(addressableId: $addressableId)';
}
