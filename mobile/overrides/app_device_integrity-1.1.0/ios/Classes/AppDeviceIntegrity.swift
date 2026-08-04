import CryptoKit
import DeviceCheck
import Foundation

/// App Attest wrapper that provisions one Secure Enclave key per install and
/// answers every later challenge with a local assertion.
///
/// `DCAppAttestService.generateKey` and `attestKey` are network round trips to
/// Apple's attestation servers and Apple rate limits them, so both run only on
/// first use. The key identifier and attestation object are cached in
/// `UserDefaults` rather than the Keychain, which survives uninstall: a wiped
/// cache cannot strand a reinstall on a key that is already gone. A restored
/// device backup can still hand back an identifier without its Secure Enclave
/// key, since those keys never leave the device — that is what the
/// `DCError.invalidKey` re-provisioning path below exists for. Subsequent
/// challenges go through `generateAssertion`, which stays on device.
@available(iOS 14.0, *)
final class AppDeviceIntegrity {
    /// A provisioned App Attest key plus the attestation object Apple issued
    /// for it. `isFresh` marks the credential Apple minted during this call —
    /// its attestation already binds the current challenge, so no separate
    /// assertion is needed.
    private struct Credential {
        let keyID: String
        let attestation: String
        let isFresh: Bool
    }

    private enum StorageKey {
        static let keyID = "AppAttestKeyIdentifier"
        static let attestation = "AppAttestAttestationObject"
        static let pendingKeyID = "AppAttestPendingKeyIdentifier"
        static let pendingClientDataHash = "AppAttestPendingClientDataHash"
    }

    let inputString: String
    var attestationString: String?
    var assertionString: String?

    private let attestService = DCAppAttestService.shared
    private var keyID: String?

    /// Guards provisioning so concurrent challenges share one key instead of
    /// racing `generateKey` and burning Apple's rate limit. The cache is static
    /// alongside it: the queue is shared, so the store it drains into has to be.
    private static let defaults = UserDefaults.standard
    private static let lock = NSLock()
    private static var isProvisioning = false
    private static var pendingProvisioning: [(Credential?) -> Void] = []

    /// Identifies the in-flight provisioning round.
    ///
    /// Incremented by whichever of the real callback or the watchdog finishes
    /// the round first, so the loser becomes a no-op instead of draining a
    /// queue that now belongs to a later round.
    private static var provisioningRound = 0

    /// How long a provisioning round may run before it is failed.
    ///
    /// `generateKey` and `attestKey` are network calls to Apple, and nothing
    /// here can cancel them. Without this, one wedged callback strands every
    /// later proof behind `isProvisioning` until the app restarts — turning a
    /// single native hang into a process-wide proof stall.
    private static let provisioningTimeout: DispatchTimeInterval = .seconds(30)

    init?(challengeString: String) {
        self.inputString = challengeString

        guard attestService.isSupported else {
            print("[!] Attest service not available")
            return nil
        }
    }

    func keyIdentifier() -> String {
        keyID ?? Self.defaults.string(forKey: StorageKey.keyID) ?? "Error in Key ID"
    }

    private var challengeHash: Data {
        Data(SHA256.hash(data: Data(inputString.utf8)))
    }

    func generateKeyAndAttest(completion: @escaping (Bool) -> Void) {
        resolveCredential(replacing: nil) { [weak self] credential in
            guard let self = self, let credential = credential else {
                completion(false)
                return
            }
            self.bind(credential, allowReprovision: true, completion: completion)
        }
    }

    /// Ties [credential] to the current challenge, re-provisioning once if the
    /// cached key turns out to be dead.
    private func bind(
        _ credential: Credential,
        allowReprovision: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        keyID = credential.keyID
        attestationString = credential.attestation

        if credential.isFresh {
            completion(true)
            return
        }

        makeAssertion(keyID: credential.keyID) { [weak self] assertion, errorCode in
            guard let self = self else {
                completion(false)
                return
            }

            if let assertion = assertion {
                self.assertionString = assertion
                completion(true)
                return
            }

            // Anything but a dead key is a transient failure; re-provisioning
            // would only spend another rate-limited key generation.
            guard allowReprovision, errorCode == .invalidKey else {
                completion(false)
                return
            }

            print("App Attest key no longer valid, re-provisioning")
            self.resolveCredential(replacing: credential.keyID) { refreshed in
                guard let refreshed = refreshed else {
                    completion(false)
                    return
                }
                self.bind(refreshed, allowReprovision: false, completion: completion)
            }
        }
    }

    private func makeAssertion(
        keyID: String,
        completion: @escaping (String?, DCError.Code?) -> Void
    ) {
        attestService.generateAssertion(keyID, clientDataHash: challengeHash) { assertion, error in
            if let error = error {
                print("Assertion error: \(error.localizedDescription)")
                completion(nil, (error as? DCError)?.code)
                return
            }

            guard let assertion = assertion else {
                print("No assertion object received")
                completion(nil, nil)
                return
            }

            completion(assertion.base64EncodedString(), nil)
        }
    }

    /// Hands back the install's credential, provisioning one if the cache is
    /// empty. Pass the key that just failed as [staleKeyID] to replace it.
    private func resolveCredential(
        replacing staleKeyID: String?,
        completion: @escaping (Credential?) -> Void
    ) {
        Self.lock.lock()

        // Clear only while the cache still points at the key that failed. Two
        // assertions can fail on the same dead key, and dropping the
        // replacement the first recovery already stored would spend another
        // rate-limited key generation for nothing.
        if let staleKeyID = staleKeyID,
           Self.defaults.string(forKey: StorageKey.keyID) == staleKeyID {
            Self.defaults.removeObject(forKey: StorageKey.keyID)
            Self.defaults.removeObject(forKey: StorageKey.attestation)
        }

        if let keyID = Self.defaults.string(forKey: StorageKey.keyID),
           let attestation = Self.defaults.string(forKey: StorageKey.attestation) {
            Self.lock.unlock()
            completion(Credential(keyID: keyID, attestation: attestation, isFresh: false))
            return
        }

        Self.pendingProvisioning.append(completion)

        if Self.isProvisioning {
            Self.lock.unlock()
            return
        }

        Self.isProvisioning = true
        let round = Self.provisioningRound
        Self.lock.unlock()

        Self.startProvisioningWatchdog(for: round)
        provision { credential in
            Self.finishProvisioning(with: credential, round: round)
        }
    }

    /// Fails [round] if it is still running once [provisioningTimeout] elapses.
    private static func startProvisioningWatchdog(for round: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + provisioningTimeout
        ) {
            finishProvisioning(with: nil, round: round, timedOut: true)
        }
    }

    /// Provisions the install's credential, resuming a key an earlier round
    /// generated but could not attest.
    ///
    /// Apple rate limits `generateKey`, so the identifier is recorded before
    /// `attestKey` runs and only dropped once the key is either attested or
    /// rejected outright. A throttled or offline `attestKey` therefore leaves a
    /// resumable key behind rather than burning a second generation on the next
    /// proof, which is what Apple's guidance to retry attestation with the same
    /// key and client data hash amounts to here.
    private func provision(completion: @escaping (Credential?) -> Void) {
        guard let pending = Self.pendingKey() else {
            generateAndAttest(completion: completion)
            return
        }

        attest(keyID: pending.keyID, clientDataHash: pending.clientDataHash) { credential, keyIsDead in
            // A resumed key Apple no longer recognises — a device restore
            // between the two calls — can never be attested. Start over
            // instead of leaving this proof unattested for nothing.
            guard keyIsDead else {
                completion(credential)
                return
            }
            self.generateAndAttest(completion: completion)
        }
    }

    private func generateAndAttest(completion: @escaping (Credential?) -> Void) {
        // Captured strongly on purpose: a provisioning round must reach
        // `finishProvisioning` to release the queued challenges, even if the
        // instance that started it is already gone.
        attestService.generateKey { keyIdentifier, error in
            if let error = error {
                print("Key generation error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let keyIdentifier = keyIdentifier else {
                print("Failed to generate key identifier")
                completion(nil)
                return
            }

            let clientDataHash = self.challengeHash
            Self.storePendingKey(keyID: keyIdentifier, clientDataHash: clientDataHash)

            self.attest(keyID: keyIdentifier, clientDataHash: clientDataHash) { credential, _ in
                completion(credential)
            }
        }
    }

    /// Attests [keyID] against the [clientDataHash] it was generated for.
    ///
    /// [clientDataHash] predates the current challenge whenever a previous
    /// round generated the key but failed to attest it: Apple attests a key
    /// once, for the request it accepted, so a retry has to repeat the original
    /// inputs. The attestation that comes back then binds that earlier proof,
    /// which is why only a hash matching the current challenge yields a fresh
    /// credential — anything else has to sign its own assertion.
    ///
    /// The completion's second value reports a key Apple rejected as dead,
    /// which no later retry can revive.
    private func attest(
        keyID: String,
        clientDataHash: Data,
        completion: @escaping (Credential?, Bool) -> Void
    ) {
        attestService.attestKey(keyID, clientDataHash: clientDataHash) { attestation, error in
            if let error = error {
                print("Attestation error: \(error.localizedDescription)")

                let keyIsDead = (error as? DCError)?.code == .invalidKey
                if keyIsDead {
                    Self.clearPendingKey()
                }
                completion(nil, keyIsDead)
                return
            }

            guard let attestation = attestation else {
                print("No attestation object received")
                completion(nil, false)
                return
            }

            completion(
                Credential(
                    keyID: keyID,
                    attestation: attestation.base64EncodedString(),
                    isFresh: clientDataHash == self.challengeHash
                ),
                false
            )
        }
    }

    // The pending slot is only ever touched inside a provisioning round, and
    // `isProvisioning` admits one of those at a time, so these need no lock of
    // their own.
    private static func pendingKey() -> (keyID: String, clientDataHash: Data)? {
        guard let keyID = defaults.string(forKey: StorageKey.pendingKeyID),
              let clientDataHash = defaults.data(forKey: StorageKey.pendingClientDataHash) else {
            return nil
        }
        return (keyID, clientDataHash)
    }

    private static func storePendingKey(keyID: String, clientDataHash: Data) {
        defaults.set(keyID, forKey: StorageKey.pendingKeyID)
        defaults.set(clientDataHash, forKey: StorageKey.pendingClientDataHash)
    }

    private static func clearPendingKey() {
        defaults.removeObject(forKey: StorageKey.pendingKeyID)
        defaults.removeObject(forKey: StorageKey.pendingClientDataHash)
    }

    /// Ends [round], storing [credential] and releasing everyone queued behind
    /// it.
    ///
    /// Runs at most once per round: the real callback and the watchdog race,
    /// and the loser returns without touching the queue. A late real
    /// credential is therefore dropped rather than stored, which costs one
    /// rate-limited generation on the next proof but keeps the cache from
    /// gaining a key no waiter was told about.
    private static func finishProvisioning(
        with credential: Credential?,
        round: Int,
        timedOut: Bool = false
    ) {
        lock.lock()

        guard isProvisioning, round == provisioningRound else {
            lock.unlock()
            return
        }
        provisioningRound &+= 1

        if let credential = credential {
            defaults.set(credential.keyID, forKey: StorageKey.keyID)
            defaults.set(credential.attestation, forKey: StorageKey.attestation)
            clearPendingKey()
        }

        isProvisioning = false
        let waiting = pendingProvisioning
        pendingProvisioning = []
        lock.unlock()

        if timedOut {
            print("App Attest provisioning timed out, failing \(waiting.count) queued challenge(s)")
        }

        // Only the caller that triggered provisioning gets the fresh-attestation
        // shortcut, and only when Apple bound the attestation to that caller's
        // challenge — a resumed key carries the hash of the proof that
        // generated it. Everyone else must sign themselves with an assertion.
        for (index, callback) in waiting.enumerated() {
            guard let credential = credential else {
                callback(nil)
                continue
            }
            callback(
                Credential(
                    keyID: credential.keyID,
                    attestation: credential.attestation,
                    isFresh: index == 0 && credential.isFresh
                )
            )
        }
    }
}
