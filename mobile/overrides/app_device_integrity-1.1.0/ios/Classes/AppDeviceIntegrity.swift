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
        resolveCredential(forceRefresh: false) { [weak self] credential in
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
            self.resolveCredential(forceRefresh: true) { refreshed in
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

    private func resolveCredential(
        forceRefresh: Bool,
        completion: @escaping (Credential?) -> Void
    ) {
        Self.lock.lock()

        if forceRefresh {
            Self.defaults.removeObject(forKey: StorageKey.keyID)
            Self.defaults.removeObject(forKey: StorageKey.attestation)
        } else if let keyID = Self.defaults.string(forKey: StorageKey.keyID),
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
        Self.lock.unlock()

        provision { credential in
            self.finishProvisioning(with: credential)
        }
    }

    private func provision(completion: @escaping (Credential?) -> Void) {
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

            self.attestService.attestKey(keyIdentifier, clientDataHash: self.challengeHash) { attestation, error in
                if let error = error {
                    print("Attestation error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                guard let attestation = attestation else {
                    print("No attestation object received")
                    completion(nil)
                    return
                }

                completion(
                    Credential(
                        keyID: keyIdentifier,
                        attestation: attestation.base64EncodedString(),
                        isFresh: true
                    )
                )
            }
        }
    }

    private func finishProvisioning(with credential: Credential?) {
        Self.lock.lock()

        if let credential = credential {
            Self.defaults.set(credential.keyID, forKey: StorageKey.keyID)
            Self.defaults.set(credential.attestation, forKey: StorageKey.attestation)
        }

        Self.isProvisioning = false
        let waiting = Self.pendingProvisioning
        Self.pendingProvisioning = []
        Self.lock.unlock()

        // Only the caller that triggered provisioning gets the fresh-attestation
        // shortcut; the queued challenges were not bound by Apple's attestation
        // and must sign themselves with an assertion.
        for (index, callback) in waiting.enumerated() {
            guard let credential = credential else {
                callback(nil)
                continue
            }
            callback(
                Credential(
                    keyID: credential.keyID,
                    attestation: credential.attestation,
                    isFresh: index == 0
                )
            )
        }
    }
}
