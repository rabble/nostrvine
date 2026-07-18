// ABOUTME: Cubit signalling a home-tab retap so the feed refreshes and the
// ABOUTME: bottom nav renders a spinner while the refresh is in flight.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum HomeFeedRetapStatus { idle, refreshing }

class HomeFeedRetapState extends Equatable {
  const HomeFeedRetapState({this.status = HomeFeedRetapStatus.idle});

  final HomeFeedRetapStatus status;

  bool get isRefreshing => status == HomeFeedRetapStatus.refreshing;

  HomeFeedRetapState copyWith({HomeFeedRetapStatus? status}) =>
      HomeFeedRetapState(status: status ?? this.status);

  @override
  List<Object?> get props => [status];
}

/// Coordinates the home-tab retap gesture with the feed refresh.
///
/// `VineBottomNav` calls [request] when the home tab is tapped while already
/// active. The nav renders a spinning refresh arrow while
/// [HomeFeedRetapState.isRefreshing] and ignores further retaps until the
/// refresh completes.
///
/// `VideoFeedView` (in `video_feed_page.dart`) listens via a `BlocListener`:
/// on [request] it refreshes the feed, scrolls back to the top, and calls
/// [completeRefresh] once the refresh settles.
///
/// Provided above `AppShell` (see `shell.dart`) so the bottom nav and the
/// home branch's feed reach the same instance.
class HomeFeedRetapCubit extends Cubit<HomeFeedRetapState> {
  HomeFeedRetapCubit() : super(const HomeFeedRetapState());

  /// Requests a feed refresh. No-op while a refresh is already in flight.
  void request() {
    if (state.isRefreshing) return;
    emit(state.copyWith(status: HomeFeedRetapStatus.refreshing));
  }

  /// Marks the in-flight refresh as settled.
  void completeRefresh() {
    emit(state.copyWith(status: HomeFeedRetapStatus.idle));
  }
}
