import AVFoundation
import Flutter

/// Bridges an `AVPlayer` to Flutter's texture system.
///
/// Uses `AVPlayerItemVideoOutput` to pull `CVPixelBuffer` frames from
/// the player and exposes them via the `FlutterTexture` protocol.
/// A `CADisplayLink` drives the frame polling loop.
final class VideoTextureOutput: NSObject, FlutterTexture, AVPlayerItemOutputPullDelegate {

    private let registry: FlutterTextureRegistry
    private var onFirstFrame: (() -> Void)?

    /// The ID registered with Flutter's texture registry.
    private(set) var textureId: Int64 = 0

    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var latestPixelBuffer: CVPixelBuffer?
    private var hasDeliveredFirstFrame = false
    private weak var player: AVPlayer?
    /// Tracks the item the output is currently attached to so we can
    /// remove it before attaching to a new item.
    private weak var attachedItem: AVPlayerItem?
    /// The exact CMTime passed to the most recent forceRefresh call.
    /// Used in outputMediaDataWillChange so we request the frame at the
    /// precise seek target rather than player.currentTime(), which can
    /// differ when a new seek is already in flight.
    private var pendingSeekTime: CMTime = .invalid

    /// Deadline until which the display link bypasses `hasNewPixelBuffer`
    /// and calls `copyPixelBuffer` directly on every tick.
    ///
    /// AVFoundation must decode all frames from the nearest keyframe
    /// to the seek target before it can serve a pixel buffer. For clips
    /// with long GOPs (up to ~2 s keyframe interval), this stall can
    /// last 300–500 ms. During that window `hasNewPixelBuffer` stays
    /// false, freezing the Flutter texture. A 600 ms force window covers
    /// any realistic GOP length at both 60 Hz and 120 Hz (ProMotion).
    private var forceRefreshDeadline: Date = .distantPast

    /// Number of display-link ticks that failed `copyPixelBuffer` inside
    /// the current force window. Non-zero when the window expires means
    /// the compositor is permanently stuck at this seek position.
    private var forceWindowFailCount = 0

    /// Called when the force window expires without delivering a frame.
    /// Provides the stuck CMTime so the caller can retry with tolerance.
    var onSeekStuck: ((CMTime) -> Void)?

    init(
        registry: FlutterTextureRegistry,
        onFirstFrame: (() -> Void)? = nil
    ) {
        self.registry = registry
        self.onFirstFrame = onFirstFrame

        super.init()

        // Register after super.init() so `self` is fully initialised
        // and `copyPixelBuffer()` can be called immediately.
        textureId = registry.register(self)
    }

    // MARK: - Public API

    /// Attaches the video output to a player item so frames can be
    /// pulled from it.
    func attach(to item: AVPlayerItem) {
        // Remove the old output from the item it was actually added to.
        if let old = videoOutput, let prev = attachedItem {
            prev.remove(old)
        }

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA,
        ]
        let output = AVPlayerItemVideoOutput(
            pixelBufferAttributes: attrs
        )
        output.setDelegate(self, queue: .main)
        item.add(output)
        videoOutput = output
        attachedItem = item
        hasDeliveredFirstFrame = false
        pendingSeekTime = .invalid
    }

    /// Attaches the display-link driven polling loop to the player.
    /// Call once after the player is created.
    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startDisplayLink()
    }

    /// Opens a 600 ms window after a seek during which the display link
    /// bypasses `hasNewPixelBuffer`. Also fires a delegate notification
    /// so the frame arrives even when the player is fully paused.
    ///
    /// Pass the exact seek target so outputMediaDataWillChange can use
    /// it directly instead of player.currentTime(), which might already
    /// reflect a newer seek.
    func forceRefresh(for seekTime: CMTime) {
        pendingSeekTime = seekTime
        forceRefreshDeadline = Date(timeIntervalSinceNow: 0.6)
        forceWindowFailCount = 0
        videoOutput?.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    // MARK: - AVPlayerItemOutputPullDelegate

    /// Called after a seek flushes the output queue.
    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        (output as? AVPlayerItemVideoOutput)?
            .requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    /// Called when the compositor has a decoded frame ready.
    ///
    /// Fires even when the player is fully paused — it is the most
    /// reliable path for frames after exact seeks on a paused
    /// `AVMutableComposition` with `AVVideoComposition`.
    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        guard let videoOutput = sender as? AVPlayerItemVideoOutput else {
            return
        }
        // Prefer the stored seek target. Fall back to currentTime only if
        // we have no pending seek (e.g. notification from outputSequenceWasFlushed).
        let targetTime: CMTime
        if pendingSeekTime.isValid {
            targetTime = pendingSeekTime
        } else if let p = player {
            targetTime = p.currentTime()
        } else {
            return
        }
        guard let pixelBuffer = videoOutput.copyPixelBuffer(
            forItemTime: targetTime,
            itemTimeForDisplay: nil
        ) else {
            videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
            return
        }
        pendingSeekTime = .invalid
        forceRefreshDeadline = .distantPast
        forceWindowFailCount = 0
        deliverFrame(pixelBuffer)
    }

    /// Cleans up display link and unregisters the texture.
    func dispose() {
        stopDisplayLink()
        registry.unregisterTexture(textureId)
        videoOutput = nil
        latestPixelBuffer = nil
        onFirstFrame = nil
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }

    // MARK: - Display link

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(
            target: self,
            selector: #selector(onDisplayLink)
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func deliverFrame(_ pixelBuffer: CVPixelBuffer) {
        latestPixelBuffer = pixelBuffer
        registry.textureFrameAvailable(textureId)
        if !hasDeliveredFirstFrame {
            hasDeliveredFirstFrame = true
            onFirstFrame?()
        }
    }

    @objc private func onDisplayLink() {
        guard let output = videoOutput,
              let player else { return }

        let itemTime = player.currentTime()

        if Date() < forceRefreshDeadline {
            if let pixelBuffer = output.copyPixelBuffer(
                forItemTime: itemTime,
                itemTimeForDisplay: nil
            ) {
                pendingSeekTime = .invalid
                forceRefreshDeadline = .distantPast
                forceWindowFailCount = 0
                deliverFrame(pixelBuffer)
            } else {
                forceWindowFailCount += 1
            }
            return
        }

        if forceWindowFailCount > 0 {
            let stuckTime = itemTime
            forceWindowFailCount = 0
            DispatchQueue.main.async { [weak self] in
                self?.onSeekStuck?(stuckTime)
            }
        }

        guard output.hasNewPixelBuffer(forItemTime: itemTime) else { return }

        if let pixelBuffer = output.copyPixelBuffer(
            forItemTime: itemTime,
            itemTimeForDisplay: nil
        ) {
            deliverFrame(pixelBuffer)
        }
    }
}
