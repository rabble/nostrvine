// ABOUTME: Cubit polling the featured Explore tab configuration.
// ABOUTME: Repository owns caching and gating; this owns cadence and lifecycle.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

part 'featured_tabs_state.dart';

/// Keeps the featured Explore tab in sync with its server configuration.
///
/// Polls at the server-supplied cadence and refetches on app foreground so a
/// backend kill switch takes effect without an app update. Eligibility and
/// cache staleness are the repository's job — this cubit only decides *when*
/// to ask and republishes the answer.
class FeaturedTabsCubit extends Cubit<FeaturedTabsState> {
  /// Creates the cubit over [repository].
  ///
  /// [viewerIsMinor] is read at each refresh rather than captured once, so an
  /// age-up or account switch is reflected on the next poll.
  FeaturedTabsCubit({
    required FeaturedTabsRepository repository,
    required bool Function() viewerIsMinor,
  }) : _repository = repository,
       _viewerIsMinor = viewerIsMinor,
       super(const FeaturedTabsState());

  final FeaturedTabsRepository _repository;
  final bool Function() _viewerIsMinor;

  Timer? _pollTimer;

  /// Fetches the configuration and reschedules the poll timer.
  ///
  /// Safe to call repeatedly; the UI calls it on mount and on app foreground.
  Future<void> refresh() async {
    if (isClosed) return;
    emit(state.copyWith(status: FeaturedTabsStatus.loading, tab: state.tab));

    final snapshot = await _repository.refresh(
      viewerIsMinor: _viewerIsMinor(),
    );
    if (isClosed) return;

    emit(
      FeaturedTabsState(
        status: FeaturedTabsStatus.resolved,
        tab: snapshot.tab,
        pollInterval: snapshot.pollInterval,
      ),
    );
    _schedulePoll(snapshot.pollInterval);
  }

  void _schedulePoll(Duration interval) {
    _pollTimer?.cancel();
    if (interval <= Duration.zero) return;
    _pollTimer = Timer(interval, refresh);
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _pollTimer = null;
    return super.close();
  }
}
