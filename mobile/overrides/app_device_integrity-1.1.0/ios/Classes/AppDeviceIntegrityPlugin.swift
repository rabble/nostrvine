import Flutter
import UIKit

@available(iOS 14.0, *)
public class AppDeviceIntegrityPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_attestation", binaryMessenger: registrar.messenger())
        let instance: AppDeviceIntegrityPlugin = AppDeviceIntegrityPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAttestationServiceSupport":
            guard let args = call.arguments as? [String: Any],
                let challengeString = args["challengeString"] as? String
            else {
                result(FlutterError(code: "-3", message: "Invalid arguments", details: nil))
                return
            }

            // App Attest hits the Secure Enclave and Apple's attestation
            // servers. Flutter delivers channel calls on the main thread, so
            // doing that work here froze the UI for ~200ms after every
            // recording. Stay off-main and only hop back to deliver the result.
            DispatchQueue.global(qos: .userInitiated).async {
                guard let deviceIntegrity = AppDeviceIntegrity(challengeString: challengeString) else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "-4", message: "Failed to initialize AppDeviceIntegrity", details: nil))
                    }
                    return
                }

                // Directly generate key and attest
                deviceIntegrity.generateKeyAndAttest { success in
                    DispatchQueue.main.async {
                        if success {
                            // Attestation successful, return the attestationString
                            let attestationResult = [
                                "attestationString": deviceIntegrity.attestationString ?? "",
                                "keyID": deviceIntegrity.keyIdentifier()
                            ]

                            do {
                                let jsonData = try JSONEncoder().encode(attestationResult)
                                if let jsonString = String(data: jsonData, encoding: .utf8) {
                                    result(jsonString)
                                } else {
                                    result(FlutterError(code: "-6", message: "Failed to convert JSON data to String", details: nil))
                                }
                            } catch {
                                result(FlutterError(code: "-7", message: "JSON encoding error: \(error.localizedDescription)", details: nil))
                            }
                        } else {
                            // Attestation or key generation failed
                            result(FlutterError(code: "-5", message: "Attestation failed", details: nil))
                        }
                    }
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

}
