// ABOUTME: State for CommunitySuggestCubit — the "Help classify this" flow.
// ABOUTME: Selected labels, already-suggested labels, and submission status.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/content_label.dart';

/// Lifecycle status of the community content-warning suggestion flow.
enum CommunitySuggestStatus {
  /// Nothing loaded yet.
  initial,

  /// Loading the viewer's existing suggestions.
  loading,

  /// Ready for the viewer to select and submit labels.
  ready,

  /// A submission is in flight.
  submitting,

  /// The suggestion published successfully.
  success,

  /// Loading or submission failed.
  failure,
}

/// State for `CommunitySuggestCubit`.
class CommunitySuggestState extends Equatable {
  /// Creates the state.
  const CommunitySuggestState({
    this.status = CommunitySuggestStatus.initial,
    this.selected = const {},
    this.alreadySuggested = const {},
  });

  /// Current lifecycle status.
  final CommunitySuggestStatus status;

  /// Labels the viewer has selected but not yet submitted.
  final Set<ContentLabel> selected;

  /// Normalized label values the viewer has already suggested for this video.
  final Set<String> alreadySuggested;

  /// Whether the current selection can be submitted.
  bool get canSubmit =>
      selected.isNotEmpty && status != CommunitySuggestStatus.submitting;

  /// Returns a copy with the given fields replaced.
  CommunitySuggestState copyWith({
    CommunitySuggestStatus? status,
    Set<ContentLabel>? selected,
    Set<String>? alreadySuggested,
  }) => CommunitySuggestState(
    status: status ?? this.status,
    selected: selected ?? this.selected,
    alreadySuggested: alreadySuggested ?? this.alreadySuggested,
  );

  @override
  List<Object?> get props => [status, selected, alreadySuggested];
}
