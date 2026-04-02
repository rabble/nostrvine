import AVFoundation

/// Manages audio overlay tracks that play alongside the main video.
///
/// Each overlay is an independent `AVPlayer` instance positioned and
/// synced to the main video timeline. Drift correction keeps audio
/// aligned within ``driftThreshold``.
final class AudioOverlayManager {

    private var overlays: [AudioOverlayEntry] = []
    private let driftThreshold: Double = 0.25

    /// Replaces all audio overlays with the given track definitions.
    func setTracks(from tracksRaw: [[String: Any]]) {
        disposeAll()

        for map in tracksRaw {
            guard let uri = map["uri"] as? String else { continue }
            let vol = (map["volume"] as? NSNumber)?.floatValue ?? 1.0
            let videoStartMs = (map["videoStartMs"] as? NSNumber)?.doubleValue ?? 0
            let videoEndMs = (map["videoEndMs"] as? NSNumber)?.doubleValue
            let trackStartMs = (map["trackStartMs"] as? NSNumber)?.doubleValue ?? 0
            let trackEndMs = (map["trackEndMs"] as? NSNumber)?.doubleValue

            let url: URL
            if uri.hasPrefix("/") {
                url = URL(fileURLWithPath: uri)
            } else if let parsed = URL(string: uri) {
                url = parsed
            } else {
                continue
            }

            let overlay = AVPlayer(playerItem: AVPlayerItem(url: url))
            overlay.volume = vol

            overlays.append(AudioOverlayEntry(
                player: overlay,
                videoStartSec: videoStartMs / 1000.0,
                videoEndSec: videoEndMs.map { $0 / 1000.0 },
                trackStartSec: trackStartMs / 1000.0,
                trackEndSec: trackEndMs.map { $0 / 1000.0 }
            ))
        }
    }

    /// Sets volume for the overlay at `index`.
    func setTrackVolume(at index: Int, volume: Float) {
        guard index >= 0, index < overlays.count else { return }
        overlays[index].player.volume = volume
    }

    /// Resumes playback of currently active overlays at the given speed.
    func resumeActive(speed: Double) {
        for entry in overlays where entry.isActive {
            entry.player.play()
            entry.player.rate = Float(speed)
        }
    }

    /// Pauses all overlay players and marks them inactive.
    func pauseAndDeactivateAll() {
        for entry in overlays {
            entry.player.pause()
            entry.isActive = false
        }
    }

    /// Updates playback speed on currently active overlay players.
    func setSpeed(_ speed: Double) {
        for entry in overlays where entry.isActive {
            entry.player.rate = Float(speed)
        }
    }

    /// Syncs every overlay track to the current global video position.
    ///
    /// Starts, pauses, or drift-corrects each overlay based on whether
    /// the video position falls within that track's active range.
    func update(videoPositionSec: Double, isPlaying: Bool, speed: Double) {
        for entry in overlays {
            let inRange = videoPositionSec >= entry.videoStartSec &&
                (entry.videoEndSec == nil || videoPositionSec < entry.videoEndSec!)

            if inRange && isPlaying {
                let expectedAudioSec = entry.trackStartSec +
                    (videoPositionSec - entry.videoStartSec)

                // Clamp to trackEnd if set.
                if let trackEnd = entry.trackEndSec, expectedAudioSec >= trackEnd {
                    if entry.isActive {
                        entry.player.pause()
                        entry.isActive = false
                    }
                    continue
                }

                if !entry.isActive {
                    let audioTime = CMTime(seconds: expectedAudioSec, preferredTimescale: 600)
                    entry.player.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    entry.player.play()
                    entry.player.rate = Float(speed)
                    entry.isActive = true
                } else {
                    // Correct drift.
                    let actualSec = CMTimeGetSeconds(entry.player.currentTime())
                    let drift = abs(expectedAudioSec - actualSec)
                    if drift > driftThreshold {
                        let audioTime = CMTime(seconds: expectedAudioSec, preferredTimescale: 600)
                        entry.player.seek(to: audioTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                }
            } else {
                if entry.isActive {
                    entry.player.pause()
                    entry.isActive = false
                }
            }
        }
    }

    /// Releases all overlay players and clears the list.
    func disposeAll() {
        for entry in overlays {
            entry.player.pause()
            entry.player.replaceCurrentItem(with: nil)
        }
        overlays.removeAll()
    }
}

/// Holds one audio overlay player and its scheduling metadata.
final class AudioOverlayEntry {
    let player: AVPlayer
    let videoStartSec: Double
    let videoEndSec: Double?
    let trackStartSec: Double
    let trackEndSec: Double?
    var isActive: Bool = false

    init(
        player: AVPlayer,
        videoStartSec: Double,
        videoEndSec: Double?,
        trackStartSec: Double,
        trackEndSec: Double?
    ) {
        self.player = player
        self.videoStartSec = videoStartSec
        self.videoEndSec = videoEndSec
        self.trackStartSec = trackStartSec
        self.trackEndSec = trackEndSec
    }
}
