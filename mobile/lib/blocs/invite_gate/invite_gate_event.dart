// ABOUTME: Events for the invite gate onboarding flow
// ABOUTME: Drives config loading, invite validation, and invite access state

import 'package:equatable/equatable.dart';
import 'package:openvine/models/invite_models.dart';

sealed class InviteGateEvent extends Equatable {
  const InviteGateEvent();

  @override
  List<Object?> get props => const [];
}

class InviteGateConfigRequested extends InviteGateEvent {
  const InviteGateConfigRequested({this.force = false});

  final bool force;

  @override
  List<Object?> get props => [force];
}

class InviteGateCodeSubmitted extends InviteGateEvent {
  const InviteGateCodeSubmitted(this.rawCode);

  final String rawCode;

  @override
  List<Object?> get props => [rawCode];
}

class InviteGateGeneralErrorSet extends InviteGateEvent {
  const InviteGateGeneralErrorSet(this.error);

  final String? error;

  @override
  List<Object?> get props => [error];
}

class InviteGateTransientCleared extends InviteGateEvent {
  const InviteGateTransientCleared();
}

class InviteGateAccessGranted extends InviteGateEvent {
  const InviteGateAccessGranted(this.grant);

  final InviteAccessGrant grant;

  @override
  List<Object?> get props => [grant];
}

class InviteGateAccessCleared extends InviteGateEvent {
  const InviteGateAccessCleared();
}
