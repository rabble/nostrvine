// ABOUTME: Region/language gate that plays the mandatory recording start/stop
// ABOUTME: system sound (iOS); see RecordingSoundPolicy for the JP/KR rationale

import AudioToolbox
import Foundation

extension CameraController {
    /// Apple's system sound IDs for the camera's record start/stop tones.
    fileprivate enum RecordingSoundID {
        static let start: SystemSoundID = 1117
        static let stop: SystemSoundID = 1118
    }

    /// Whether the device region or language mandates the recording sound
    /// (Japan/South Korea). Callers gate both the start and stop tones on this.
    var isRecordingSoundMandatory: Bool {
        RecordingSoundPolicy.requiresRecordingSound(
            regionCode: Self.currentRegionCode(),
            languageCode: Self.currentLanguageCode()
        )
    }

    /// Plays the recording-start tone, invoking `completion` once it finishes.
    /// Ungated — the caller checks `isRecordingSoundMandatory` first — so the
    /// caller can hold audio capture until the tone ends and keep it out of the
    /// clip. `completion` runs on an internal audio queue.
    ///
    /// Note: as a system sound this respects the ring/silent switch. Making it
    /// non-silenceable is not achievable from a third-party app on iOS (the
    /// OS-forced camera sound is reserved for Apple's own Camera app); see the
    /// investigation in the PR discussion.
    func playRecordingStartTone(completion: @escaping () -> Void) {
        AudioServicesPlaySystemSoundWithCompletion(
            RecordingSoundID.start,
            completion
        )
    }

    /// Plays the mandatory recording-stop tone when the device region or
    /// language requires it; a no-op everywhere else. Fired after
    /// `finishWriting`, past the last audio sample, so it never lands in the
    /// clip and needs no audio suppression.
    func playRecordingStopSoundIfMandatory() {
        guard isRecordingSoundMandatory else { return }
        AudioServicesPlaySystemSound(RecordingSoundID.stop)
    }

    /// The current device region identifier (e.g. `"JP"`), or `nil` if
    /// unavailable. Reflects the user's Region setting — the closest app-level
    /// signal, since the hardware region lock is not exposed by API.
    private static func currentRegionCode() -> String? {
        if #available(iOS 16.0, *) {
            return Locale.current.region?.identifier
        }
        return (Locale.current as NSLocale).object(forKey: .countryCode)
            as? String
    }

    /// The current device language identifier (e.g. `"ja"`), or `nil` if
    /// unavailable.
    private static func currentLanguageCode() -> String? {
        if #available(iOS 16.0, *) {
            return Locale.current.language.languageCode?.identifier
        }
        return (Locale.current as NSLocale).object(forKey: .languageCode)
            as? String
    }
}
