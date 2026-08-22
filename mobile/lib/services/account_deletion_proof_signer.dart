// ABOUTME: Signs the NIP-98 proof-of-key for the Keycast account-deletion retry
// ABOUTME: Pins the proof to the account whose bearer token is being spent

import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Signs the NIP-98 proof-of-key that backs the account-deletion retry.
///
/// Keycast's `DELETE /user/account` is authorized by the bearer token; this
/// proof is only offered after that token comes back 403. Lives outside
/// `AuthService` so the account pin below is unit-testable on its own, and so
/// deletion work stops accreting into an already-oversized service (#4338).
class AccountDeletionProofSigner {
  AccountDeletionProofSigner({
    required Nip98AuthService Function() buildNip98Auth,
    required String? Function() activePubkey,
  }) : _buildNip98Auth = buildNip98Auth,
       _activePubkey = activePubkey;

  /// Builds the NIP-98 service on first use.
  ///
  /// Reuses the audited kind-27235 construction in [Nip98AuthService] rather
  /// than hand-rolling a second one for a single call site. Deferred rather
  /// than eager so [dispose] does not construct one — and start its
  /// cache-cleanup timer — purely in order to tear it down.
  final Nip98AuthService Function() _buildNip98Auth;

  /// The pubkey signed in right now, sampled at each call rather than held.
  final String? Function() _activePubkey;

  Nip98AuthService? _nip98Auth;

  /// The base64 event body for a `DELETE` of [url], or null when no proof
  /// should be sent — in which case the refusal the bearer attempt earned
  /// stands.
  ///
  /// Never throws: failing to sign must not turn a refused deletion into a
  /// reported network error.
  ///
  /// Refuses unless the signer still belongs to [tokenOwnerPubkey], the
  /// account the bearer token was minted for. Signing is a remote RPC for a
  /// Keycast identity, so an account switch can land mid-flight — and pairing
  /// one account's token with another's proof on an irreversible delete is not
  /// a mistake worth leaving to whether the server happens to reject it.
  Future<String?> sign(String url, {required String? tokenOwnerPubkey}) async {
    try {
      if (tokenOwnerPubkey == null || _activePubkey() != tokenOwnerPubkey) {
        Log.warning(
          'Refusing to sign a deletion proof for a different account than the '
          'token was minted for: token owner '
          '${tokenOwnerPubkey ?? "unknown"}, signed-in account '
          '${_activePubkey() ?? "none"}',
          name: 'AccountDeletionProofSigner',
          category: LogCategory.auth,
        );
        return null;
      }

      final token = await (_nip98Auth ??= _buildNip98Auth()).createAuthToken(
        url: url,
        method: HttpMethod.delete,
      );

      // Ordered before the account check so a signer that produced nothing is
      // not reported as a proof being discarded.
      if (token == null) {
        Log.warning(
          'Could not sign NIP-98 proof for account deletion; '
          'the refused bearer attempt stands',
          name: 'AccountDeletionProofSigner',
          category: LogCategory.auth,
        );
        return null;
      }

      // The check that carries the weight: the entry check only proves the
      // accounts matched before a call that can take seconds.
      if (_activePubkey() != tokenOwnerPubkey) {
        Log.warning(
          'Discarding a deletion proof signed for ${pubkeyForLogs(tokenOwnerPubkey)}: the '
          'signed-in account changed to ${_activePubkey() ?? "none"} while it '
          'was being signed',
          name: 'AccountDeletionProofSigner',
          category: LogCategory.auth,
        );
        return null;
      }

      return token.token;
    } catch (e) {
      Log.warning(
        'NIP-98 proof signing threw for account deletion: $e',
        name: 'AccountDeletionProofSigner',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  void dispose() {
    _nip98Auth?.dispose();
    _nip98Auth = null;
  }
}
