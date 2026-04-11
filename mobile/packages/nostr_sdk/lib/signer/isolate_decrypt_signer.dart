import 'nostr_signer.dart';

/// Optional capability for signers that can expose a local private key to an
/// isolate-safe decrypt pipeline.
abstract interface class IsolateDecryptSigner implements NostrSigner {
  bool get canDecryptInIsolate;
  T withPrivateKeyHex<T>(T Function(String hex) operation);
}
