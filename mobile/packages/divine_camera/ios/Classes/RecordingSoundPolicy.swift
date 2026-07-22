// ABOUTME: Pure region/language policy for the mandatory recording start/stop
// ABOUTME: sound (Japan JEITA/carrier + Korea KCC rules); shared decision logic

import Foundation

/// Pure decision logic for the region-mandated recording sound.
///
/// Divine records through a custom `AVAssetWriter` pipeline
/// (`CameraController`) instead of the system camera UI, so iOS does not
/// automatically emit the record start/stop sound that phones sold in Japan and
/// South Korea must play. Japan enforces this via JEITA/carrier device
/// certification; South Korea via KCC type-approval (a ~65 dB, non-silenceable
/// tone). Both target devices sold in-region, and Apple satisfies them at the
/// OS level for its own camera — which leaves a custom pipeline responsible for
/// replicating the behavior.
///
/// The decision is region-first with the device language as a widening
/// safeguard: the hardware region lock is not exposed by API, so a JP/KR device
/// whose owner switched their Region setting away is missed by region alone.
/// Falling back to the `ja`/`ko` device language catches that case, at the cost
/// of also firing for JP/KR-language users elsewhere.
///
/// This is the only branch worth verifying, so it lives here as pure logic — no
/// AVFoundation, no AudioToolbox — mirroring `MediaSessionScopePolicy` and
/// covered by the Runner test target (the divine_camera Swift tests do not run
/// in CI).
public enum RecordingSoundPolicy {
    /// Region codes whose devices must play a non-silenceable recording sound.
    public static let mandatorySoundRegionCodes: Set<String> = ["JP", "KR"]

    /// Device language codes that also mandate the sound, as a widening
    /// safeguard when the region setting has been changed away from JP/KR.
    public static let mandatorySoundLanguageCodes: Set<String> = ["ja", "ko"]

    /// Whether a device with this `regionCode` or `languageCode` must play the
    /// recording start/stop sound.
    ///
    /// `regionCode` is the current `Locale` region identifier (e.g. `"JP"`);
    /// `languageCode` the current language identifier (e.g. `"ja"`). Either
    /// match is sufficient. `nil`/empty values are ignored. Matching is
    /// case-insensitive.
    public static func requiresRecordingSound(
        regionCode: String?,
        languageCode: String?
    ) -> Bool {
        if let regionCode, !regionCode.isEmpty,
            mandatorySoundRegionCodes.contains(regionCode.uppercased()) {
            return true
        }
        if let languageCode, !languageCode.isEmpty,
            mandatorySoundLanguageCodes.contains(languageCode.lowercased()) {
            return true
        }
        return false
    }
}
