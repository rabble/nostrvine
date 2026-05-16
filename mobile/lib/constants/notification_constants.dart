/// Constants shared by the notification list-item widgets and the
/// type-icon / avatar-stack primitives.
class NotificationConstants {
  /// Diameter of an actor avatar rendered inside a notification row.
  static const double avatarSize = 32;

  /// Corner radius for a notification avatar (Figma: 0.4 × [avatarSize]).
  static const double avatarCornerRadius = 12.8;

  /// Empirical breakpoint where 320px-wide notification rows start clipping
  /// once the follow-back button or trailing thumbnail shares the main row.
  static const double largeTextStackThreshold = 1.35;
}
