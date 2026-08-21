import AVFoundation

/// Manages audio overlay tracks that play alongside the main video.
///
/// Each overlay is an independent `AVPlayer` instance positioned and
/// synced to the main video timeline. Drift correction keeps audio
/// aligned within ``driftThreshold``.
final class AudioOverlayManager {

    private let log = DivineVideoPlayerLog.shared
    private var overlays: [AudioOverlayEntry] = []
    private let driftThreshold: Double = 0.25
    private let logName = "AudioOverlayManager"

    /// Replaces all audio overlays with the given track definitions.
    func setTracks(from tracksRaw: [[String: Any]]) {
        log.info(
            "Replacing audio overlays with \(tracksRaw.count) track(s)",
            name: logName
        )
        disposeAll()

        for (index, map) in tracksRaw.enumerated() {
            guard let uri = map["uri"] as? String else {
                log.warning(
                    "Audio overlay track \(index): skipping track with no uri",
                    name: logName
                )
                continue
            }
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
                log.warning(
                    "Audio overlay track \(index): skipping invalid uri",
                    name: logName
                )
                continue
            }

            let overlay = AVPlayer(playerItem: AVPlayerItem(url: url))
            overlay.volume = vol

            overlays.append(AudioOverlayEntry(
                player: overlay,
                videoStartSec: videoStartMs / 1000.0,
                videoEndSec: videoEndMs.map { $0 / 1000.0 },
                trackStartSec: trackStartMs / 1000.0,
                trackEndSec: trackEndMs.map { $0 / 1000.0 },
                trackIndex: index
            ))
        }
    }

    /// Sets volume for the overlay at `index`.
    func setTrackVolume(at index: Int, volume: Float) {
        guard index >= 0, index < overlays.count else {
            log.warning(
                "Audio overlay index \(index): volume update out of bounds",
                name: logName
            )
            return
        }
        log.debug(
            "Audio overlay track \(overlays[index].trackIndex): volume set to \(volume)",
            name: logName
        )
        overlays[index].player.volume = volume
    }

    /// Resumes playback of currently active overlays at the given speed.
    func resumeActive(speed: Double) {
        for entry in overlays where entry.isActive {
            log.info(
                "Audio overlay track \(entry.trackIndex): resuming at speed \(speed)",
                name: logName
            )
            entry.player.play()
            entry.player.rate = Float(speed)
            reportStatusIfChanged(for: entry, context: "resume")
        }
    }

    /// Pauses all overlay players and marks them inactive.
    func pauseAndDeactivateAll() {
        for entry in overlays {
            entry.player.pause()
            entry.isActive = false
            log.info(
                "Audio overlay track \(entry.trackIndex): paused and deactivated",
                name: logName
            )
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
        guard !overlays.isEmpty else { return }
        // Runs every 0.2 seconds on the main queue for every player instance.
        // Console-only so user bug reports retain capacity for state
        // transitions and failures, and debug-only because a console trace
        // never reaches a bug report in the first place.
        #if DEBUG
        print("[AudioOverlay] update: position \(videoPositionSec)")
        #endif
        for entry in overlays {
            reportStatusIfChanged(for: entry, context: "update")
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
                        log.info(
                            "Audio overlay track \(entry.trackIndex): reached track end",
                            name: logName
                        )
                    }
                    continue
                }

                if !entry.isActive {
                    let audioTime = CMTime(seconds: expectedAudioSec, preferredTimescale: 600)
                    log.info(
                        "Audio overlay track \(entry.trackIndex): starting playback " +
                            "at \(expectedAudioSec)s, speed \(speed)",
                        name: logName
                    )
                    seek(entry, to: audioTime, reason: "playback start")
                    entry.player.play()
                    entry.player.rate = Float(speed)
                    entry.isActive = true
                    reportStatusIfChanged(for: entry, context: "playback start")
                } else {
                    // Correct drift.
                    let actualSec = CMTimeGetSeconds(entry.player.currentTime())
                    let drift = abs(expectedAudioSec - actualSec)
                    if drift > driftThreshold {
                        #if DEBUG
                        print(
                            "[AudioOverlay] track \(entry.trackIndex): " +
                                "drift correction \(drift)s"
                        )
                        #endif
                        let audioTime = CMTime(seconds: expectedAudioSec, preferredTimescale: 600)
                        seek(entry, to: audioTime, reason: "drift correction")
                    }
                }
            } else {
                if entry.isActive {
                    entry.player.pause()
                    entry.isActive = false
                    log.info(
                        "Audio overlay track \(entry.trackIndex): paused outside active range",
                        name: logName
                    )
                }
            }
        }
    }

    /// Releases all overlay players and clears the list.
    func disposeAll() {
        guard !overlays.isEmpty else { return }
        log.debug("Disposing \(overlays.count) audio overlay(s)", name: logName)
        for entry in overlays {
            entry.player.pause()
            entry.player.replaceCurrentItem(with: nil)
        }
        overlays.removeAll()
    }

    private func seek(_ entry: AudioOverlayEntry, to time: CMTime, reason: String) {
        entry.player.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self, weak entry] completed in
            guard let self, let entry else { return }
            let message = "Audio overlay track \(entry.trackIndex): " +
                "\(reason) seek completed=\(completed)"
            if completed {
                self.log.debug(message, name: self.logName)
            } else {
                self.log.warning(message, name: self.logName)
            }
            self.reportStatusIfChanged(for: entry, context: "\(reason) seek")
        }
    }

    private func reportStatusIfChanged(
        for entry: AudioOverlayEntry,
        context: String
    ) {
        let playerStatus = entry.player.status
        let itemStatus = entry.player.currentItem?.status
        let itemError = entry.player.currentItem?.error
        let itemErrorDescription = itemError.map { error in
            let nsError = error as NSError
            return "\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)"
        }

        guard playerStatus != entry.lastPlayerStatus ||
            itemStatus != entry.lastItemStatus ||
            itemErrorDescription != entry.lastItemErrorDescription
        else {
            return
        }

        entry.lastPlayerStatus = playerStatus
        entry.lastItemStatus = itemStatus
        entry.lastItemErrorDescription = itemErrorDescription

        let errorDescription = itemErrorDescription ?? "none"
        let message = "Audio overlay track \(entry.trackIndex): \(context), " +
            "player.status=\(String(describing: playerStatus)), " +
            "currentItem.status=\(String(describing: itemStatus)), " +
            "currentItem.error=\(errorDescription)"
        if playerStatus == .failed || itemStatus == .failed || itemError != nil {
            log.error(message, name: logName)
        } else {
            log.info(message, name: logName)
        }
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
    let trackIndex: Int
    var lastPlayerStatus: AVPlayer.Status?
    var lastItemStatus: AVPlayerItem.Status?
    var lastItemErrorDescription: String?

    init(
        player: AVPlayer,
        videoStartSec: Double,
        videoEndSec: Double?,
        trackStartSec: Double,
        trackEndSec: Double?,
        trackIndex: Int
    ) {
        self.player = player
        self.videoStartSec = videoStartSec
        self.videoEndSec = videoEndSec
        self.trackStartSec = trackStartSec
        self.trackEndSec = trackEndSec
        self.trackIndex = trackIndex
    }
}
