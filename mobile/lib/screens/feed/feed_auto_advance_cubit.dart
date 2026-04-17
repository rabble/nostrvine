import 'package:equatable/equatable.dart';
import 'package:flutter/semantics.dart' show SemanticsService, TextDirection;
import 'package:flutter/widgets.dart' show BuildContext, View;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Feed-scoped runtime state for the Auto playback mode.
///
/// Owned per feed surface (home feed page / fullscreen feed) and provided
/// down the tree via `BlocProvider` so the completion listener, the rail
/// control, and the screen's orchestration logic all observe the same state.
class FeedAutoAdvanceState extends Equatable {
  const FeedAutoAdvanceState({
    this.enabled = false,
    this.suppressed = false,
    this.pendingPaginationAdvance = false,
  });

  /// Whether the user has turned Auto on for this feed.
  final bool enabled;

  /// Whether Auto is temporarily suppressed by a non-swipe interaction
  /// (e.g. opening a comment sheet). Cleared on the next manual swipe.
  final bool suppressed;

  /// Whether an auto-advance is queued waiting for the next pagination page
  /// to land. Cleared once the advance executes or Auto is disabled.
  final bool pendingPaginationAdvance;

  /// True when Auto should actually drive the feed forward right now.
  bool get isEffectivelyActive => enabled && !suppressed;

  FeedAutoAdvanceState copyWith({
    bool? enabled,
    bool? suppressed,
    bool? pendingPaginationAdvance,
  }) {
    return FeedAutoAdvanceState(
      enabled: enabled ?? this.enabled,
      suppressed: suppressed ?? this.suppressed,
      pendingPaginationAdvance:
          pendingPaginationAdvance ?? this.pendingPaginationAdvance,
    );
  }

  @override
  List<Object?> get props => [enabled, suppressed, pendingPaginationAdvance];
}

/// Feed-scoped Cubit that owns the Auto playback toggle and transient flags.
class FeedAutoAdvanceCubit extends Cubit<FeedAutoAdvanceState> {
  FeedAutoAdvanceCubit() : super(const FeedAutoAdvanceState());

  /// Sets the Auto toggle directly. Disabling also clears suppression and
  /// any queued pagination advance.
  void setEnabled({required bool enabled}) {
    if (state.enabled == enabled) return;

    if (!enabled) {
      emit(const FeedAutoAdvanceState());
      return;
    }

    emit(state.copyWith(enabled: true, suppressed: false));
  }

  /// Toggle behaviour for the rail control.
  ///
  /// - If Auto is enabled and suppressed, tapping resumes (not disables).
  /// - Otherwise, flips the enabled bit.
  void toggle() {
    if (state.enabled && state.suppressed) {
      emit(state.copyWith(suppressed: false));
      return;
    }

    setEnabled(enabled: !state.enabled);
  }

  /// Temporarily suppress Auto for a non-swipe interaction.
  void suppressForInteraction() {
    if (!state.enabled || state.suppressed) return;

    emit(
      state.copyWith(suppressed: true, pendingPaginationAdvance: false),
    );
  }

  /// Resume Auto after the user performs a manual swipe.
  void resumeAfterSwipe() {
    if (!state.enabled || !state.suppressed) return;

    emit(
      state.copyWith(suppressed: false, pendingPaginationAdvance: false),
    );
  }

  /// Mark that the feed needs to advance once the next page lands.
  void markPendingPaginationAdvance() {
    if (state.pendingPaginationAdvance) return;
    emit(state.copyWith(pendingPaginationAdvance: true));
  }

  /// Clear the queued pagination advance (typically after it fires).
  void clearPendingPaginationAdvance() {
    if (!state.pendingPaginationAdvance) return;
    emit(state.copyWith(pendingPaginationAdvance: false));
  }
}

/// Announce the new Auto playback toggle state to screen readers.
///
/// Called from the screen right after [FeedAutoAdvanceCubit.toggle] because
/// the rail control is small and its visual state may be easy to miss.
void announceAutoAdvanceToggle(BuildContext context, {required bool enabled}) {
  final l10n = context.l10n;
  final message = enabled
      ? l10n.videoActionEnableAutoAdvance
      : l10n.videoActionDisableAutoAdvance;
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    TextDirection.ltr,
  );
}
