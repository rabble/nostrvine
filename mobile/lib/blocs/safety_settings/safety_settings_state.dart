// ABOUTME: State for SafetySettingsCubit — toggle prefs + reactive blocklist
// ABOUTME: and labeler lists for the safety settings moderation hub.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the safety settings screen.
enum SafetySettingsStatus { loading, ready }

/// State for `SafetySettingsCubit`.
///
/// The cubit owns three independent toggles ([isAgeVerified],
/// [isPeopleIFollowEnabled], [showDivineHostedOnly]) plus two reactive lists
/// ([customLabelers], [blockedUsers]) that the cubit refreshes from streams
/// and after every mutation (label add/remove, block/unblock). The previous
/// `_buildBlockedUsersSection` `ref.watch(blocklistVersionProvider)` rebuild
/// hook is replaced by a `stateStream` subscription on
/// `ContentBlocklistRepository` so the UI no longer needs to read the
/// repository imperatively in `build`.
class SafetySettingsState extends Equatable {
  const SafetySettingsState({
    this.status = SafetySettingsStatus.loading,
    this.isAgeVerified = false,
    this.isAdultContentLocked = false,
    this.isPeopleIFollowEnabled = false,
    this.showDivineHostedOnly = true,
    this.customLabelers = const <String>{},
    this.blockedUsers = const <String>{},
  });

  final SafetySettingsStatus status;
  final bool isAgeVerified;

  /// True when the account is a protected minor: the adult-content toggle is
  /// locked off and cannot be enabled (#175).
  final bool isAdultContentLocked;
  final bool isPeopleIFollowEnabled;
  final bool showDivineHostedOnly;

  /// Subscribed labeler pubkeys excluding the built-in Divine labeler.
  final Set<String> customLabelers;

  /// Pubkeys currently blocked at runtime
  /// (from `ContentBlocklistRepository.runtimeBlockedUsers`).
  final Set<String> blockedUsers;

  SafetySettingsState copyWith({
    SafetySettingsStatus? status,
    bool? isAgeVerified,
    bool? isAdultContentLocked,
    bool? isPeopleIFollowEnabled,
    bool? showDivineHostedOnly,
    Set<String>? customLabelers,
    Set<String>? blockedUsers,
  }) {
    return SafetySettingsState(
      status: status ?? this.status,
      isAgeVerified: isAgeVerified ?? this.isAgeVerified,
      isAdultContentLocked: isAdultContentLocked ?? this.isAdultContentLocked,
      isPeopleIFollowEnabled:
          isPeopleIFollowEnabled ?? this.isPeopleIFollowEnabled,
      showDivineHostedOnly: showDivineHostedOnly ?? this.showDivineHostedOnly,
      customLabelers: customLabelers ?? this.customLabelers,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isAgeVerified,
    isAdultContentLocked,
    isPeopleIFollowEnabled,
    showDivineHostedOnly,
    customLabelers,
    blockedUsers,
  ];
}
