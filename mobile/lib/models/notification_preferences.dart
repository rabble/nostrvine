import 'package:equatable/equatable.dart';

/// User preferences for push notification types.
///
/// Maps to kind 3083 events per the NIP-XX push notification draft.
/// The push service uses the kinds list to filter which notification
/// types to deliver via FCM.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.likesEnabled = true,
    this.commentsEnabled = true,
    this.followsEnabled = true,
    this.mentionsEnabled = true,
    this.repostsEnabled = true,
  });

  /// Create preferences from a list of enabled Nostr event kinds.
  ///
  /// Kind mapping:
  /// - 7: reactions (likes)
  /// - 1: text notes (comments and mentions)
  /// - 3: contact list (follows)
  /// - 16: reposts
  ///
  /// Comments and mentions both use kind 1. When kind 1 is present,
  /// both are enabled. When absent, both are disabled.
  /// Known limitation: the push service filters by kind number only,
  /// so comments and mentions cannot be toggled independently.
  factory NotificationPreferences.fromKindsList(List<int> kinds) {
    return NotificationPreferences(
      likesEnabled: kinds.contains(7),
      commentsEnabled: kinds.contains(1),
      followsEnabled: kinds.contains(3),
      mentionsEnabled: kinds.contains(1),
      repostsEnabled: kinds.contains(16),
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      likesEnabled: json['likesEnabled'] as bool? ?? true,
      commentsEnabled: json['commentsEnabled'] as bool? ?? true,
      followsEnabled: json['followsEnabled'] as bool? ?? true,
      mentionsEnabled: json['mentionsEnabled'] as bool? ?? true,
      repostsEnabled: json['repostsEnabled'] as bool? ?? true,
    );
  }

  final bool likesEnabled;
  final bool commentsEnabled;
  final bool followsEnabled;
  final bool mentionsEnabled;
  final bool repostsEnabled;

  /// Convert to the kinds list format expected by the push service.
  ///
  /// Returns deduplicated list of Nostr event kinds.
  List<int> toKindsList() {
    final kinds = <int>{};
    if (likesEnabled) kinds.add(7);
    if (commentsEnabled || mentionsEnabled) kinds.add(1);
    if (followsEnabled) kinds.add(3);
    if (repostsEnabled) kinds.add(16);
    return kinds.toList()..sort();
  }

  Map<String, dynamic> toJson() {
    return {
      'likesEnabled': likesEnabled,
      'commentsEnabled': commentsEnabled,
      'followsEnabled': followsEnabled,
      'mentionsEnabled': mentionsEnabled,
      'repostsEnabled': repostsEnabled,
    };
  }

  NotificationPreferences copyWith({
    bool? likesEnabled,
    bool? commentsEnabled,
    bool? followsEnabled,
    bool? mentionsEnabled,
    bool? repostsEnabled,
  }) {
    return NotificationPreferences(
      likesEnabled: likesEnabled ?? this.likesEnabled,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      followsEnabled: followsEnabled ?? this.followsEnabled,
      mentionsEnabled: mentionsEnabled ?? this.mentionsEnabled,
      repostsEnabled: repostsEnabled ?? this.repostsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    likesEnabled,
    commentsEnabled,
    followsEnabled,
    mentionsEnabled,
    repostsEnabled,
  ];
}
