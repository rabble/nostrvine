// ABOUTME: Describes an account restore that resolved to the wrong identity.
// ABOUTME: Lets auth callers route failed restores back through full login.

import 'package:openvine/models/auth_state.dart';

/// Thrown when a returning-user sign-in does not restore the requested account.
class AccountRestoreFailedException implements Exception {
  const AccountRestoreFailedException(
    this.pubkeyHex,
    this.resolvedState, {
    this.resolvedPubkeyHex,
  });

  final String pubkeyHex;
  final AuthState resolvedState;
  final String? resolvedPubkeyHex;

  @override
  String toString() =>
      'AccountRestoreFailedException: sign-in for $pubkeyHex resolved to '
      '$resolvedState'
      '${resolvedPubkeyHex == null ? '' : ' as $resolvedPubkeyHex'} '
      'instead of the requested account';
}
