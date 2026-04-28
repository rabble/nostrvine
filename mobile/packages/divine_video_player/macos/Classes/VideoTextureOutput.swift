import AVFoundation
import FlutterMacOS
import QuartzCore

/// Bridges an `AVPlayer` to Flutter's texture system on macOS.
///
/// Uses `AVPlayerItemVideoOutput` to pull `CVPixelBuffer` frames from
/// the player and exposes them via the `FlutterTexture` protocol.
/// A timer drives the frame polling loop (macOS has no `CADisplayLink`).
final class VideoTextureOutput: NSObject, FlutterTexture, AVPlayerItemOutputPullDelegate {

    private let registry: FlutterTextureRegistry
    private var onFirstFrame: (() -> Void)?

    /// The ID registered with Flutter's texture registry.
    private(set) var textureId: Int64

    private var videoOutput: AVPlayerItemVideoOutput?
    private var pollTimer: Timer?
    private var latestPixelBuffer: CVPixelBuffer?
    private var hasDeliveredFirstFrame = false
    private weak var player: AVPlayer?
    /// Item the output is currently attached to, so we can detach cleanly.
    private weak var attachedItem: AVPlayerItem?
    /// Exact seek target from the most recent `forceRefresh`; preferred over
    /// `player.currentTime()` because a newer seek may already be in flight.
    private var pendingSeekTime: CMTime = .invalid

    /// Window during which the poll loop bypasses `hasNewPixelBuffer`
    /// and tries `copyPixelBuffer` on every tick. Covers the GOP-decode
    /// stall after an exact seek (up to ~500 ms on long-GOP clips).
    /// Uses `CACurrentMediaTime()` (monotonic) so NTP/TZ clock jumps
    /// can't collapse or extend the window.
    private var forceRefreshDeadline: CFTimeInterval = 0

    /// Failed `copyPixelBuffer` ticks within the current force window.
    /// Non-zero at expiry means the compositor is stuck at this time.
    private var forceWindowFailCount = 0

    /// Marks the current force window as a tolerant-seek retry. When
    /// `true`, expiry without a frame does NOT fire `onSeekStuck` again,
    /// preventing an infinite retry loop on persistently broken content.
    private var forceWindowIsRetry = false

    /// Fired when the force window expires without a frame; caller should
    /// retry the seek with tolerance. Suppressed for retry windows.
    var onSeekStuck: ((CMTime) -> Void)?

    init(
        registry: FlutterTextureRegistry,
        onFirstFrame: (() -> Void)? = nil
    ) {
        self.registry = registry
        self.onFirstFrame = onFirstFrame
        self.textureId = -1

        super.init()

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

    /// Attaches the polling loop to the player.
    /// Call once after the player is created.
    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startPolling()
    }

    /// Opens a 600 ms force window after a seek and requests a delegate
    /// notification, so the texture updates even while paused. Pass the
    /// exact seek target — used directly in `outputMediaDataWillChange`.
    /// Pass `isRetry: true` for a tolerant-seek retry; suppresses
    /// `onSeekStuck` on expiry to break recovery loops.
    func forceRefresh(for seekTime: CMTime, isRetry: Bool = false) {
        pendingSeekTime = seekTime
        forceRefreshDeadline = CACurrentMediaTime() + 0.6
        forceWindowFailCount = 0
        forceWindowIsRetry = isRetry
        videoOutput?.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    // MARK: - AVPlayerItemOutputPullDelegate

    /// Called after a seek flushes the output queue.
    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        (output as? AVPlayerItemVideoOutput)?
            .requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    /// Fires even on a paused player — most reliable frame path after an
    /// exact seek on an `AVMutableComposition` with `AVVideoComposition`.
    func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
        guard let videoOutput = sender as? AVPlayerItemVideoOutput else {
            return
        }
        // Prefer the stored seek target; fall back to currentTime only when
        // there's no pending seek (e.g. notification from a flush).
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
        forceRefreshDeadline = 0
        forceWindowFailCount = 0
        deliverFrame(pixelBuffer)
    }

    /// Cleans up the timer and unregisters the texture.
    func dispose() {
        stopPolling()
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

    // MARK: - Polling

    private func startPolling() {
        guard pollTimer == nil else { return }
        // ~60 fps polling to match typical display refresh rate.
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.pollFrame()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollFrame() {
        guard let output = videoOutput,
              let player else { return }

        let itemTime = player.currentTime()

        if CACurrentMediaTime() < forceRefreshDeadline {
            if let pixelBuffer = output.copyPixelBuffer(
                forItemTime: itemTime,
                itemTimeForDisplay: nil
            ) {
                pendingSeekTime = .invalid
                forceRefreshDeadline = 0
                forceWindowFailCount = 0
                deliverFrame(pixelBuffer)
            } else {
                forceWindowFailCount += 1
            }
            return
        }

        if forceWindowFailCount > 0 {
            let stuckTime = itemTime
            let wasRetry = forceWindowIsRetry
            forceWindowFailCount = 0
            forceWindowIsRetry = false
            if !wasRetry {
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekStuck?(stuckTime)
                }
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

    private func deliverFrame(_ pixelBuffer: CVPixelBuffer) {
        latestPixelBuffer = pixelBuffer
        registry.textureFrameAvailable(textureId)
        if !hasDeliveredFirstFrame {
            hasDeliveredFirstFrame = true
            onFirstFrame?()
        }
    }
}
