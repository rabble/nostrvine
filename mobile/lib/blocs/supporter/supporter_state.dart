// ABOUTME: State for the Divine supporter screen.
// ABOUTME: Tracks tiers, current entitlement, and purchase/restore lifecycle.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum SupporterStatus { idle, loading, purchasing, restoring, active, error }

/// Typed reason for a supporter-screen failure, mapped from validator
/// exceptions so the UI can show specific copy.
enum SupporterFailure {
  storeUnavailable,
  purchaseFailed,
  purchasePending,
  restoreFailed,
  unknown;

  static SupporterFailure fromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('unavailable')) return SupporterFailure.storeUnavailable;
    if (lower.contains('pending')) return SupporterFailure.purchasePending;
    if (lower.contains('restore')) return SupporterFailure.restoreFailed;
    if (lower.contains('cancel') || lower.contains('fail')) {
      return SupporterFailure.purchaseFailed;
    }
    return SupporterFailure.unknown;
  }
}

class SupporterState extends Equatable {
  const SupporterState({
    this.tiers = const [],
    this.entitlement = SupporterEntitlement.inactive,
    this.status = SupporterStatus.idle,
    this.failure,
  });

  /// Purchasable supporter tiers loaded from the store.
  final List<SupporterTier> tiers;

  /// The current supporter entitlement.
  final SupporterEntitlement entitlement;

  final SupporterStatus status;
  final SupporterFailure? failure;

  bool get isSupporter => entitlement.isSupporter;
  bool get isBusy =>
      status == SupporterStatus.purchasing ||
      status == SupporterStatus.restoring ||
      status == SupporterStatus.loading;
  bool get hasTiers => tiers.isNotEmpty;

  SupporterState copyWith({
    List<SupporterTier>? tiers,
    SupporterEntitlement? entitlement,
    SupporterStatus? status,
    SupporterFailure? failure,
    bool clearFailure = false,
  }) {
    return SupporterState(
      tiers: tiers ?? this.tiers,
      entitlement: entitlement ?? this.entitlement,
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [tiers, entitlement, status, failure];
}
