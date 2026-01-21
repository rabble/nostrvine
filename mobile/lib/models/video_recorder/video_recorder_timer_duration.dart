/// Timer duration options for delayed recording.
enum TimerDuration {
  /// No timer delay.
  off,

  /// 3 second delay.
  three,

  /// 10 second delay.
  ten;

  /// Path to SVG asset representing the timer duration.
  String get iconPath => switch (this) {
    .off => 'assets/icon/timer.svg',
    .three => 'assets/icon/timer_3.svg',
    .ten => 'assets/icon/timer_10.svg',
  };

  /// Duration value for the timer.
  Duration get duration => switch (this) {
    .off => Duration.zero,
    .three => const Duration(seconds: 3),
    .ten => const Duration(seconds: 10),
  };
}
