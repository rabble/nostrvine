// ABOUTME: State for the invite gate onboarding flow
// ABOUTME: Tracks server config, validated invite access, and invite input errors

import 'package:equatable/equatable.dart';
import 'package:openvine/models/invite_models.dart';

enum InviteGateConfigStatus { initial, loading, success, failure }

class InviteGateState extends Equatable {
  const InviteGateState({
    this.configStatus = InviteGateConfigStatus.initial,
    this.config,
    this.accessGrant,
    this.isValidatingCode = false,
    this.inviteCodeError,
    this.generalError,
  });

  final InviteGateConfigStatus configStatus;
  final InviteClientConfig? config;
  final InviteAccessGrant? accessGrant;
  final bool isValidatingCode;
  final String? inviteCodeError;
  final String? generalError;

  bool get isConfigLoading => configStatus == InviteGateConfigStatus.loading;
  bool get hasConfig =>
      configStatus == InviteGateConfigStatus.success && config != null;
  bool get hasAccessGrant => accessGrant != null;

  InviteGateState copyWith({
    InviteGateConfigStatus? configStatus,
    InviteClientConfig? config,
    bool clearConfig = false,
    InviteAccessGrant? accessGrant,
    bool clearAccessGrant = false,
    bool? isValidatingCode,
    String? inviteCodeError,
    bool clearInviteCodeError = false,
    String? generalError,
    bool clearGeneralError = false,
  }) {
    return InviteGateState(
      configStatus: configStatus ?? this.configStatus,
      config: clearConfig ? null : (config ?? this.config),
      accessGrant: clearAccessGrant ? null : (accessGrant ?? this.accessGrant),
      isValidatingCode: isValidatingCode ?? this.isValidatingCode,
      inviteCodeError: clearInviteCodeError
          ? null
          : (inviteCodeError ?? this.inviteCodeError),
      generalError: clearGeneralError
          ? null
          : (generalError ?? this.generalError),
    );
  }

  @override
  List<Object?> get props => [
    configStatus,
    config,
    accessGrant,
    isValidatingCode,
    inviteCodeError,
    generalError,
  ];
}
