// ABOUTME: Cubit owning explore tab availability, ordering, and name<->index
// ABOUTME: mapping so the screen widget stays a thin tabs scaffold.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'explore_tabs_state.dart';

/// Coordinates which explore tabs are present and their order.
///
/// Tab availability is dynamic: Classics, For You, and Apps tabs appear based
/// on async feature/platform checks, which shifts the index of every later
/// tab. To keep callers from reasoning about raw indices, this cubit owns the
/// ordered tab-name list and the name<->index conversion, and treats tab
/// identity as the stable key (never the index).
class ExploreTabsCubit extends Cubit<ExploreTabsState> {
  /// Creates the cubit with all optional tabs initially unavailable.
  ExploreTabsCubit() : super(const ExploreTabsState());

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
}
