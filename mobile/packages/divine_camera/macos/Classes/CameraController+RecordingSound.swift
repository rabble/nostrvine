// ABOUTME: Plays the region-mandated recording start/stop system sound (macOS)
// ABOUTME: Gated by RecordingSoundPolicy; see that file for the JP/KR rationale

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
    /// recorded clip. `completion` runs on an internal audio queue.
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

    /// The current device region identifier (e.g. `"JP"`), or `nil`. Uses the
    /// key-based `NSLocale` accessor so it compiles on the package's macOS
    /// 10.14 floor without an availability gate.
    private static func currentRegionCode() -> String? {
        (Locale.current as NSLocale).object(forKey: .countryCode) as? String
    }

    /// The current device language identifier (e.g. `"ja"`), or `nil`.
    private static func currentLanguageCode() -> String? {
        (Locale.current as NSLocale).object(forKey: .languageCode) as? String
    }
}
