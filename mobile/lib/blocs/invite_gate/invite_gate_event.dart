// ABOUTME: Events for the invite gate onboarding flow
// ABOUTME: Drives invite validation and invite access state

import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/models/invite_models.dart';

sealed class InviteGateEvent extends Equatable {
  const InviteGateEvent();

  @override
  List<Object?> get props => const [];
}

class InviteGateCodeSubmitted extends InviteGateEvent {
  const InviteGateCodeSubmitted(this.rawCode);

  final String rawCode;

  @override
  List<Object?> get props => [rawCode];
}

/// Seeds (or clears) the block-level failure shown on the gate.
///
/// Takes a reason code, never text. The one caller is an inbound deep link
/// carrying `?error=`; see [InviteGateError.unknown] for why its payload is
/// discarded rather than displayed.
class InviteGateGeneralErrorSet extends InviteGateEvent {
  const InviteGateGeneralErrorSet(this.error);

  final InviteGateError? error;

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
