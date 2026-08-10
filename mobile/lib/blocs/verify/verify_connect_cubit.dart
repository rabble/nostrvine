// ABOUTME: Drives linking one platform — OAuth login or proof post — and
// ABOUTME: publishes the confirmed claim to the identity event.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/verify/verify_proof_input.dart';
import 'package:profile_repository/profile_repository.dart';

part 'verify_connect_state.dart';

/// Opens an OAuth authorization URL and returns its HTTPS callback.
///
/// A `null` callback means the user closed or cancelled the browser session.
typedef VerifyOAuthLauncher = Future<Uri?> Function(Uri authorizationUrl);

/// Links a single platform to the signed-in identity.
///
/// Both routes end the same way: the verifier confirms the account, and only
/// then is the `i` tag published. The web flow leaves publishing as a second
/// button, which is how people end up verified with no checkmark (#6154).
class VerifyConnectCubit extends Cubit<VerifyConnectState> {
  /// Creates a [VerifyConnectCubit] for [platform].
  VerifyConnectCubit({
    required IdentityClaimsRepository repository,
    required String pubkey,
    required VerifierPlatform platform,
    required VerifyOAuthLauncher launchOAuth,
    required String oauthReturnUrl,
  }) : _repository = repository,
       _pubkey = pubkey,
       _launchOAuth = launchOAuth,
       _oauthReturnUrl = oauthReturnUrl,
       super(VerifyConnectState(platform: platform));

  final IdentityClaimsRepository _repository;
  final String _pubkey;
  final VerifyOAuthLauncher _launchOAuth;
  final String _oauthReturnUrl;

  /// Records the account handle the user is claiming.
  void identityChanged(String identity) {
    emit(state.copyWith(identity: identity.trim(), clearError: true));
  }

  /// Records the proof URL or id backing the claim.
  void proofChanged(String proof) {
    emit(state.copyWith(proof: proof.trim(), clearError: true));
  }

  /// Asks the verifier to check the proof post, then publishes the claim.
  Future<void> submitProof() async {
    if (state.isBusy || !state.canSubmitProof) return;

    // A pasted post link has to be taken apart before it is sent: most
    // verifiers rebuild the URL from the handle and a bare id, so a link in
    // the proof field looks up a URL that cannot exist.
    final input = state.normalizedInput;
    if (input.problem != null) {
      return _fail(switch (input.problem!) {
        VerifyProofProblem.telegramNotPublic =>
          VerifyConnectError.telegramNotPublic,
      });
    }
    final claim = IdentityClaim(
      pubkey: _pubkey,
      platform: state.platform.key,
      identity: input.identity,
      proof: input.proof,
    );

    emit(
      state.copyWith(status: VerifyConnectStatus.verifying, clearError: true),
    );
    final VerificationResult result;
    try {
      result = await _repository.verifyClaim(claim);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      return _fail(VerifyConnectError.verifierUnreachable);
    }

    if (!result.verified) {
      // The verifier's reason is specific ("author does not match", "npub not
      // found") but free-form English, so it guides triage rather than the
      // user. Dropping it entirely leaves a rejection with no way to tell
      // which of the two happened.
      addError(
        StateError(
          'Verifier rejected ${claim.platform}:${claim.identity} — '
          '${result.error ?? 'no reason given'}',
        ),
        StackTrace.current,
      );
      return _fail(VerifyConnectError.proofRejected);
    }
    await _publish(claim);
  }

  /// Runs the platform's OAuth login, then publishes the claim it confirms.
  Future<void> connectWithOAuth() async {
    if (state.isBusy) return;
    if (state.platform.key == 'bluesky' && state.identity.isEmpty) {
      return _fail(VerifyConnectError.handleRequired);
    }

    emit(
      state.copyWith(status: VerifyConnectStatus.authorizing, clearError: true),
    );

    // Twitter and YouTube ship an OAuth route the deployment has no
    // credentials for. Without this check the browser session opens on the
    // verifier's 503 page and never comes back.
    final available = await _repository.canStartOAuth(
      platform: state.platform.key,
      pubkey: _pubkey,
      returnUrl: _oauthReturnUrl,
      handle: state.identity.isEmpty ? null : state.identity,
    );
    if (!available) return _fail(VerifyConnectError.oauthUnavailable);

    final Uri? callback;
    try {
      callback = await _launchOAuth(
        _repository.oauthStartUri(
          platform: state.platform.key,
          pubkey: _pubkey,
          returnUrl: _oauthReturnUrl,
          handle: state.identity.isEmpty ? null : state.identity,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      return _fail(VerifyConnectError.oauthFailed);
    }

    if (callback == null) {
      emit(state.copyWith(status: VerifyConnectStatus.editing));
      return;
    }

    final params = callback.queryParameters;
    final identity = params['identity'] ?? '';
    // A success the provider could not name would publish a claim nothing can
    // ever verify, so it is treated as a refusal rather than a link.
    if (params['oauth_verified'] != 'true' || identity.isEmpty) {
      // The verifier's reason is free-form and not fit to show, but without it
      // in the log a provider-side refusal is undiagnosable.
      addError(
        StateError(
          'Verifier OAuth refused ${state.platform.key}: '
          '${params['oauth_error'] ?? 'no reason given'}',
        ),
        StackTrace.current,
      );
      return _fail(VerifyConnectError.oauthFailed);
    }

    await _publish(
      IdentityClaim(
        pubkey: _pubkey,
        platform: state.platform.key,
        identity: identity,
        proof: IdentityClaim.oauthProof,
      ),
    );
  }

  Future<void> _publish(IdentityClaim claim) async {
    emit(state.copyWith(status: VerifyConnectStatus.publishing));
    try {
      await _repository.publishClaim(claim);
      emit(
        state.copyWith(
          status: VerifyConnectStatus.linked,
          identity: claim.identity,
          linkedClaim: claim,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      _fail(
        error is IdentityClaimReadException
            ? VerifyConnectError.linksUnreadable
            : VerifyConnectError.publishFailed,
      );
    }
  }

  void _fail(VerifyConnectError error) {
    emit(
      state.copyWith(
        status: VerifyConnectStatus.editing,
        error: error,
        errorAttempt: state.errorAttempt + 1,
      ),
    );
  }
}
