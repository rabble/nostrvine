// ABOUTME: State for the invite gate onboarding flow
// ABOUTME: Tracks validated invite access and invite input failure reasons

import 'package:equatable/equatable.dart';
import 'package:openvine/models/invite_models.dart';

/// Why the invite code the user typed was rejected.
///
/// Shown against the code field. Never carries a message string — the rule in
/// `state_management.md` (no error strings in state) is why this is an enum,
/// and the UI maps each case to localized copy.
enum InviteCodeError {
  /// The text is not shaped like an invite code at all.
  malformed,

  /// The server does not recognise the code.
  notFound,

  /// The code exists but has already been claimed or revoked.
  alreadyUsed,
}

/// Why the invite gate as a whole cannot let the user through.
///
/// Shown as a block message rather than against the code field, for failures
/// that are not the user's typing.
enum InviteGateError {
  /// This creator has handed out every invite they had.
  creatorFull,

  /// The code is real but no longer usable — revoked, rotated, or its creator
  /// page was disabled. The waitlist is the way forward.
  inviteUnavailable,

  /// The invite service could not give a verdict. Retryable.
  checkFailed,

  /// An upstream link reported a problem we cannot classify.
  ///
  /// This is deliberately the ONLY thing an inbound `?error=` query parameter
  /// can produce. Before #3591 that parameter's text was rendered verbatim in
  /// the auth error box, so any link could put arbitrary words inside Divine's
  /// own trusted red error surface, on a pre-auth screen. Trusted in-app
  /// recovery links use [queryValue]; untrusted text keeps only the signal that
  /// something went wrong upstream.
  unknown;

  static const _queryValues = <InviteGateError, String>{
    InviteGateError.creatorFull: 'creator_full',
    InviteGateError.inviteUnavailable: 'invite_unavailable',
    InviteGateError.checkFailed: 'check_failed',
    InviteGateError.unknown: 'unknown',
  };

  /// Stable value used by trusted in-app recovery links.
  String get queryValue => _queryValues[this]!;

  /// Parses an allowlisted in-app recovery reason from a URL.
  static InviteGateError? fromQuery(String? value) {
    for (final entry in _queryValues.entries) {
      if (entry.value == value) return entry.key;
    }
    return null;
  }
}

class InviteGateState extends Equatable {
  const InviteGateState({
    this.accessGrant,
    this.isValidatingCode = false,
    this.inviteCodeError,
    this.generalError,
  });

  final InviteAccessGrant? accessGrant;
  final bool isValidatingCode;
  final InviteCodeError? inviteCodeError;
  final InviteGateError? generalError;

  bool get hasAccessGrant => accessGrant != null;

  InviteGateState copyWith({
    InviteAccessGrant? accessGrant,
    bool clearAccessGrant = false,
    bool? isValidatingCode,
    InviteCodeError? inviteCodeError,
    bool clearInviteCodeError = false,
    InviteGateError? generalError,
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
