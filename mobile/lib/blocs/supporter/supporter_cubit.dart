// ABOUTME: Screen-scoped Cubit for the Divine supporter screen.
// ABOUTME: Loads tiers, drives subscribe/restore, and maps store exceptions.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iap_repository/iap_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/supporter/supporter_state.dart';
import 'package:openvine/services/supporter_repository.dart';

typedef SupporterAnalyticsSink = void Function(String event);

class SupporterCubit extends Cubit<SupporterState> {
  /// Creates a [SupporterCubit].
  ///
  /// [repository] owns the validator and cached entitlement.
  /// [trackEvent] is an optional analytics sink (e.g.
  /// `analyticsEventSinkProvider`); pass `_noopAnalytics` when unavailable.
  SupporterCubit({
    required SupporterRepository repository,
    SupporterAnalyticsSink trackEvent = _noopAnalytics,
  }) : _repository = repository,
       _trackEvent = trackEvent,
       super(SupporterState(entitlement: repository.current));

  final SupporterRepository _repository;
  final SupporterAnalyticsSink _trackEvent;

  StreamSubscription<SupporterEntitlement>? _entitlementSub;

  /// Begin listening to the repository's entitlement stream. Call from the
  /// screen's `initState` so external purchase updates (renewals, restores)
  /// reflect in the UI.
  void start() {
    _entitlementSub ??= _repository.changes.listen((entitlement) {
      emit(
        state.copyWith(
          entitlement: entitlement,
          status: entitlement.isSupporter
              ? SupporterStatus.active
              : state.status,
          clearFailure: entitlement.isSupporter,
        ),
      );
    });
    loadTiers();
  }

  /// Fetch the available supporter tiers from the store.
  Future<void> loadTiers() async {
    emit(state.copyWith(status: SupporterStatus.loading, clearFailure: true));
    try {
      final tiers = await _repository.validator.fetchProducts();
      emit(state.copyWith(tiers: tiers, status: SupporterStatus.idle));
    } on EntitlementException catch (e) {
      emit(
        state.copyWith(
          status: SupporterStatus.error,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
    }
  }

  /// Begin a purchase for [productId].
  Future<void> subscribe(String productId) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(status: SupporterStatus.purchasing, clearFailure: true),
    );
    _trackEvent('supporter_subscribe_tapped');
    try {
      final entitlement = await _repository.validator.purchase(productId);
      emit(
        state.copyWith(
          entitlement: entitlement,
          status: SupporterStatus.active,
          clearFailure: true,
        ),
      );
      _trackEvent('supporter_subscribe_succeeded');
    } on EntitlementException catch (e) {
      emit(
        state.copyWith(
          status: SupporterStatus.idle,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
      _trackEvent('supporter_subscribe_failed');
    }
  }

  /// Restore previous purchases tied to the store account.
  Future<void> restore() async {
    if (state.isBusy) return;
    emit(state.copyWith(status: SupporterStatus.restoring, clearFailure: true));
    _trackEvent('supporter_restore_tapped');
    try {
      await _repository.validator.restorePurchases();
      // The restored entitlement arrives on the repository stream; reset to idle
      // and let the stream listener surface the active status.
      emit(state.copyWith(status: SupporterStatus.idle));
      _trackEvent('supporter_restore_completed');
    } on EntitlementException catch (e) {
      emit(
        state.copyWith(
          status: SupporterStatus.idle,
          failure: SupporterFailure.fromMessage(e.message),
        ),
      );
      _trackEvent('supporter_restore_failed');
    }
  }

  /// Dismiss the current failure banner.
  void dismissError() {
    emit(state.copyWith(clearFailure: true));
  }

  @override
  Future<void> close() {
    _entitlementSub?.cancel();
    return super.close();
  }

  static void _noopAnalytics(String _) {}
}
