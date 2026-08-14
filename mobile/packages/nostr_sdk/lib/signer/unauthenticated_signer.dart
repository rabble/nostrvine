import '../event.dart';
import 'nostr_signer.dart';

/// Signer for the window where no identity exists: before sign-in resolves,
/// and after sign-out.
///
/// `NostrClientConfig.signer` is non-nullable, so a `NostrClient` vended
/// before an identity is known still has to put *something* in the signer
/// slot. This type fills it without pretending to be a working signer.
///
/// [getPublicKey] returns the empty string, and that is load-bearing — it is
/// what keeps `NostrClient.hasKeys` false, what makes `Nostr.ensurePublicKey`
/// throw, and what trips the owner-pubkey mismatch guards in the curated-list
/// gateway. Those three signals are the gates that keep signed-out code paths
/// from doing signed work. Do not change it to `null` or to a throw.
///
/// Every signing and encryption entry point throws [StateError] rather than
/// returning `null`, so "there is no identity" can no longer be mistaken for
/// "a real signer tried and failed" — before this type, both were the same
/// silent `null`.
class UnauthenticatedSigner implements NostrSigner {
  /// Creates the keyless signer. It holds no state, so callers may share one
  /// `const` instance.
  const UnauthenticatedSigner();

  /// The empty string, never `null`. See the class doc — this is a gate, not
  /// a placeholder value.
  @override
  Future<String?> getPublicKey() async => '';

  /// Always `null`: a keyless signer advertises no NIP-65 relay list.
  /// Local signers use the same answer; remote signers may return a relay map.
  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<Event?> signEvent(Event event) async => _noIdentity('sign an event');

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async =>
      _noIdentity('NIP-04 encrypt');

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async =>
      _noIdentity('NIP-04 decrypt');

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async =>
      _noIdentity('NIP-44 encrypt');

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async =>
      _noIdentity('NIP-44 decrypt');

  /// Intentional no-op: there is no key material or connection to release.
  @override
  void close() {}
}

/// Thrown when signed work is attempted with no identity.
///
/// [StateError] rather than an `Exception` subtype, matching the other
/// no-identity failures on this object graph (`LocalKeySigner
/// .withPrivateKeyHex`, `Nostr.ensurePublicKey`, `NostrCreatorBindingService
/// .createAssertion`). Reaching here means a caller skipped its readiness
/// gate, which is a programming error rather than an expected condition.
Never _noIdentity(String operation) {
  throw StateError(
    'No identity: cannot $operation while signed out. Gate this call on '
    'NostrClient.hasKeys, or on nostrSessionProvider.isReadyForActiveClient '
    'for anything that publishes.',
  );
}
