// ABOUTME: State for the invite gate onboarding flow
// ABOUTME: Tracks validated invite access and invite input errors

import 'package:equatable/equatable.dart';
import 'package:openvine/models/invite_models.dart';

class InviteGateState extends Equatable {
  const InviteGateState({
    this.accessGrant,
    this.isValidatingCode = false,
    this.inviteCodeError,
    this.generalError,
  });

  final InviteAccessGrant? accessGrant;
  final bool isValidatingCode;
  final String? inviteCodeError;
  final String? generalError;

  bool get hasAccessGrant => accessGrant != null;

  InviteGateState copyWith({
    InviteAccessGrant? accessGrant,
    bool clearAccessGrant = false,
    bool? isValidatingCode,
    String? inviteCodeError,
    bool clearInviteCodeError = false,
    String? generalError,
    bool clearGeneralError = false,
  }) {
    return InviteGateState(
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
    accessGrant,
    isValidatingCode,
    inviteCodeError,
    generalError,
  ];
}
