// ABOUTME: Cubit owning explore tab availability, ordering, and name<->index
// ABOUTME: mapping, plus the screen's analytics + hashtag-loading side effects.

import 'package:analytics/analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/top_hashtags_service.dart';

part 'explore_tabs_state.dart';

/// Coordinates which explore tabs are present and their order.
///
/// Tab availability is dynamic: Classics, For You, and Apps tabs appear based
/// on async feature/platform checks, which shifts the index of every later
/// tab. To keep callers from reasoning about raw indices, this cubit owns the
/// ordered tab-name list and the name<->index conversion, and treats tab
/// identity as the stable key (never the index).
///
/// It also owns the explore screen's service-touching side effects (screen
/// analytics and top-hashtag loading) so the presentation layer reaches them
/// through the cubit rather than importing services directly.
class ExploreTabsCubit extends Cubit<ExploreTabsState> {
  /// Creates the cubit. [screenAnalytics] and [topHashtags] default to their
  /// singletons; inject fakes in tests.
  ExploreTabsCubit({
    ScreenAnalyticsService? screenAnalytics,
    TopHashtagsLoader? topHashtags,
  }) : _screenAnalytics = screenAnalytics ?? ScreenAnalyticsService(),
       _topHashtags = topHashtags ?? TopHashtagsService.instance,
       super(const ExploreTabsState());

  static const _screenName = 'explore_screen';

  final ScreenAnalyticsService _screenAnalytics;
  final TopHashtagsLoader _topHashtags;

  /// Updates which optional tabs are available.
  ///
  /// No-ops (and emits nothing) when availability is unchanged so the screen
  /// only rebuilds its [TabController] when the tab set actually changes.
  void updateAvailability({
    required bool classicsAvailable,
    required bool forYouAvailable,
    required bool appsAvailable,
  }) {
    if (classicsAvailable == state.classicsAvailable &&
        forYouAvailable == state.forYouAvailable &&
        appsAvailable == state.appsAvailable) {
      return;
    }
    emit(
      state.copyWith(
        classicsAvailable: classicsAvailable,
        forYouAvailable: forYouAvailable,
        appsAvailable: appsAvailable,
      ),
    );
  }

  /// Marks the start of the explore screen load for analytics.
  void trackScreenLoad() => _screenAnalytics.startScreenLoad(_screenName);

  /// Records a tab change for analytics.
  void trackTabChange(String tabName) => _screenAnalytics.trackTabChange(
    screenName: _screenName,
    tabName: tabName,
  );

  /// Loads the top hashtags used for trending navigation.
  Future<void> loadHashtags() => _topHashtags.loadTopHashtags();
}
