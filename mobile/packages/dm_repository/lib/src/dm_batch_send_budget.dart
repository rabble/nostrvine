// ABOUTME: Time budget for a batched NIP-17 send and its legacy fallback.
// ABOUTME: Keeps batch-only bounds separate from the legacy send budget.

/// Bounds the NIP-17 batch-wrap attempt plus its serial fallback path.
///
/// A Keycast send first spends one 30-second `nip17_wrap_batch` request. A
/// transient failure then falls back to the legacy build, whose bounded-signer
/// floor is two 20-second RPCs plus 5 seconds of local crypto. The recipient
/// build therefore needs 75 seconds before any publish begins.
///
/// These transport values are restated because `dm_repository` cannot import
/// `keycast_flutter`; an app-layer regression test pins them to the real
/// Keycast constants.
abstract final class DmBatchSendBudget {
  static const int _batchRequestSeconds = 30;
  static const int _twoFallbackRequestsSeconds = 40;
  static const int _fallbackCryptoSeconds = 5;
  static const int _recipientOkConfirmSeconds = 10;
  static const int _selfWrapBuildSeconds = 20;
  static const int _selfWrapPublishSeconds = 10;
  static const int _headroomSeconds = 15;

  static const int _recipientWrapBuildSeconds =
      _batchRequestSeconds +
      _twoFallbackRequestsSeconds +
      _fallbackCryptoSeconds;

  /// Hard bound on a recipient-wrap batch attempt followed by its fallback.
  static const Duration recipientWrapBuild = Duration(
    seconds: _recipientWrapBuildSeconds,
  );

  /// Serial worst case for the bounded portion of a batched send.
  static const Duration chainWorstCase = Duration(
    seconds:
        _recipientWrapBuildSeconds +
        _recipientOkConfirmSeconds +
        _selfWrapBuildSeconds +
        _selfWrapPublishSeconds,
  );

  /// Hard backstop on a batched NIP-17 message publish.
  static const Duration messagePublishTimeout = Duration(
    seconds:
        _recipientWrapBuildSeconds +
        _recipientOkConfirmSeconds +
        _selfWrapBuildSeconds +
        _selfWrapPublishSeconds +
        _headroomSeconds,
  );
}
