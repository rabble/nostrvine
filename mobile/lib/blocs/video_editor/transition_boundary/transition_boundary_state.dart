part of 'transition_boundary_cubit.dart';

/// The frame paths shown either side of a transition preview. Each starts as a
/// placeholder (ghost frame / thumbnail) and is replaced by the exact extracted
/// boundary frame once it resolves; `null` falls back to a gradient.
class TransitionBoundaryState extends Equatable {
  const TransitionBoundaryState({this.fromFramePath, this.toFramePath});

  /// Outgoing clip's last visible frame.
  final String? fromFramePath;

  /// Incoming clip's first visible frame.
  final String? toFramePath;

  TransitionBoundaryState copyWith({
    String? fromFramePath,
    String? toFramePath,
  }) {
    return TransitionBoundaryState(
      fromFramePath: fromFramePath ?? this.fromFramePath,
      toFramePath: toFramePath ?? this.toFramePath,
    );
  }

  @override
  List<Object?> get props => [fromFramePath, toFramePath];
}
