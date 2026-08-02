// ABOUTME: State for the profile bell that subscribes to a creator's posts.
// ABOUTME: Status enum only — error text is composed in the UI layer.

part of 'notify_bell_cubit.dart';

enum NotifyBellStatus {
  /// Not loaded yet; the bell renders in its off state but is not tappable.
  initial,

  /// Subscription state is known and the bell is interactive.
  ready,

  /// A publish failed. The optimistic flip has already been reverted, so
  /// [NotifyBellState.isSubscribed] again reflects the last known truth; the
  /// UI shows a transient message off this status.
  failure,
}

class NotifyBellState extends Equatable {
  const NotifyBellState({
    this.status = NotifyBellStatus.initial,
    this.isSubscribed = false,
  });

  final NotifyBellStatus status;

  /// Whether the viewer receives new-post notifications for this creator.
  final bool isSubscribed;

  /// Whether the bell may be tapped.
  bool get isInteractive => status != NotifyBellStatus.initial;

  NotifyBellState copyWith({NotifyBellStatus? status, bool? isSubscribed}) {
    return NotifyBellState(
      status: status ?? this.status,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  @override
  List<Object?> get props => [status, isSubscribed];
}
