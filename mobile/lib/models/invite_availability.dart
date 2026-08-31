import 'package:equatable/equatable.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/constants/app_constants.dart';

/// Developer override for signup-invite availability.
enum InviteAvailabilityOverride { useServer, forceEnabled, forceDisabled }

/// Shared signup-invite availability for onboarding and signed-in surfaces.
class InviteAvailabilityState extends Equatable {
  const InviteAvailabilityState({
    this.hasResolved = false,
    this.serverMode,
    this.config,
    this.developerOverride = InviteAvailabilityOverride.useServer,
  });

  /// Whether the session has finished loading server client config.
  final bool hasResolved;

  /// Server `onboardingMode`, or null when missing or the request failed.
  final OnboardingMode? serverMode;

  /// Last loaded client config, when the request succeeded.
  final InviteClientConfig? config;

  /// In-memory developer override. Never written back to the server.
  final InviteAvailabilityOverride developerOverride;

  /// Whether signup/access invitations should be shown and enforced.
  ///
  /// Only an explicit `inviteCodeRequired` server value enables invitations.
  /// Missing, unavailable, or unknown configuration defaults to disabled.
  bool get isEnabled {
    switch (developerOverride) {
      case InviteAvailabilityOverride.forceEnabled:
        return true;
      case InviteAvailabilityOverride.forceDisabled:
        return false;
      case InviteAvailabilityOverride.useServer:
        return serverMode == OnboardingMode.inviteCodeRequired;
    }
  }

  InviteClientConfig get resolvedConfig {
    return config ??
        InviteClientConfig(
          mode: serverMode ?? OnboardingMode.open,
          supportEmail: AppConstants.supportEmail,
        );
  }

  InviteAvailabilityState copyWith({
    bool? hasResolved,
    OnboardingMode? serverMode,
    bool clearServerMode = false,
    InviteClientConfig? config,
    bool clearConfig = false,
    InviteAvailabilityOverride? developerOverride,
  }) {
    return InviteAvailabilityState(
      hasResolved: hasResolved ?? this.hasResolved,
      serverMode: clearServerMode ? null : (serverMode ?? this.serverMode),
      config: clearConfig ? null : (config ?? this.config),
      developerOverride: developerOverride ?? this.developerOverride,
    );
  }

  @override
  List<Object?> get props => [
    hasResolved,
    serverMode,
    config,
    developerOverride,
  ];
}
