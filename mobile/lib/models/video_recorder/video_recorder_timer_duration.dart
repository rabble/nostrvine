// ABOUTME: Timer duration enum for delayed recording start
// ABOUTME: Provides countdown options (off, 3s, 10s) with duration values and icons

import 'package:divine_ui/divine_ui.dart';

/// Timer duration options for delayed recording.
enum TimerDuration {
  /// No timer delay.
  off,

  /// 3 second delay.
  three,

  /// 10 second delay.
  ten;

  /// Icon representing the timer duration.
  DivineIconName get icon => switch (this) {
    .off => .timer,
    .three => .timer3,
    .ten => .timer10,
  };

  /// Duration value for the timer.
  Duration get duration => switch (this) {
    .off => Duration.zero,
    .three => const Duration(seconds: 3),
    .ten => const Duration(seconds: 10),
  };
}
