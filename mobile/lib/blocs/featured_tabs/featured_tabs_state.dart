// ABOUTME: State for FeaturedTabsCubit: the resolved featured tab, if any.
// ABOUTME: Absence is the normal case — no placeholder, no error surface.

part of 'featured_tabs_cubit.dart';

/// Lifecycle of the featured-tab configuration fetch.
enum FeaturedTabsStatus {
  /// No fetch has completed yet.
  initial,

  /// A fetch is in flight.
  loading,

  /// A fetch has completed; [FeaturedTabsState.tab] is authoritative.
  resolved,
}

/// The featured tab the Explore screen should render, if any.
class FeaturedTabsState extends Equatable {
  /// Creates a featured tabs state.
  const FeaturedTabsState({
    this.status = FeaturedTabsStatus.initial,
    this.tab,
    this.pollInterval = FeaturedTabsResponse.defaultPollInterval,
  });

  /// Fetch lifecycle.
  final FeaturedTabsStatus status;

  /// The eligible tab, or `null` when nothing should render.
  final FeaturedTabConfig? tab;

  /// Server-supplied refresh cadence.
  final Duration pollInterval;

  /// Whether a featured tab should appear in the tab bar.
  bool get hasTab => tab != null;

  /// Opaque configuration id for analytics, or `null` when no tab renders.
  String? get analyticsId => tab?.id;

  /// Returns a copy with the given overrides, clearing [tab] when it is null.
  FeaturedTabsState copyWith({
    FeaturedTabsStatus? status,
    FeaturedTabConfig? tab,
    Duration? pollInterval,
  }) {
    return FeaturedTabsState(
      status: status ?? this.status,
      tab: tab,
      pollInterval: pollInterval ?? this.pollInterval,
    );
  }

  @override
  List<Object?> get props => [status, tab, pollInterval];
}
