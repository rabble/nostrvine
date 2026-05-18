import AVFoundation
import Flutter
import os
import QuartzCore

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
    /// Item the output is currently attached to, so we can detach cleanly.
    private weak var attachedItem: AVPlayerItem?
    /// One-shot observation that triggers the initial frame pull as soon
    /// as the freshly attached item reports `.readyToPlay`. Without this,
    /// the first `copyPixelBuffer(forItemTime:)` can race the decoder
    /// initialisation on HEVC 10-bit / HDR clips and return `nil`
    /// indefinitely until something else (e.g. a loop restart) flushes
    /// the output sequence.
    private var itemStatusObservation: NSKeyValueObservation?
    /// Exact seek target from the most recent `forceRefresh`; preferred over
    /// `player.currentTime()` because a newer seek may already be in flight.
    private var pendingSeekTime: CMTime = .invalid

    /// Window during which the display link bypasses `hasNewPixelBuffer`
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

    /// Consecutive `outputMediaDataWillChange` calls that returned `nil`
    /// from `copyPixelBuffer`. Reset on flush, forceRefresh, and successful
    /// frame delivery. Capped to prevent an infinite re-arm loop when a
    /// seek target is persistently un-decodable.
    private var mediaDataRearmCount = 0
    private static let maxMediaDataRearmCount = 10

    /// Serialises access to `latestPixelBuffer`, which is written on the
    /// display-link callback (main thread) and read on Flutter's render
    /// thread via `copyPixelBuffer()`.
    private var pixelBufferLock = os_unfair_lock()

    /// Fired when the force window expires without a frame; caller should
    /// retry the seek with tolerance. Suppressed for retry windows.
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
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        // Request 32BGRA: Flutter's external-texture upload path expects
        // a BGRA `CVPixelBuffer` and renders garbage / black on YpCbCr
        // buffers. AVFoundation will color-convert 10-bit / HDR sources
        // into BGRA for us — at the cost of HDR range, but that's the
        // same tradeoff the official video_player plugin makes when it
        // doesn't pass an explicit Metal renderer.
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA,
            // Force IOSurface backing so the buffer can be uploaded to
            // the GPU as a Flutter texture without an extra copy.
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
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
        mediaDataRearmCount = 0

        // The first `copyPixelBuffer` attempt right after attach often
        // races decoder init (especially on HEVC 10-bit / HDR), and
        // returns `nil` until something flushes the output sequence —
        // which normally only happens on the next loop or seek. Watch
        // for `.readyToPlay` and explicitly request a media-data-change
        // notification so the decoder is forced to hand over the first
        // frame as soon as it's available.
        if item.status == .readyToPlay {
            output.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
        } else {
            itemStatusObservation = item.observe(
                \.status,
                options: [.new]
            ) { [weak self, weak output] item, _ in
                guard let self, let output, item.status == .readyToPlay else {
                    return
                }
                output.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
                self.itemStatusObservation?.invalidate()
                self.itemStatusObservation = nil
            }
        }
    }

    /// Attaches the display-link driven polling loop to the player.
    /// Call once after the player is created.
    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startDisplayLink()
    }

    /// Opens a 600 ms force window after a seek and requests a delegate
    /// notification, so the texture updates even while paused. Pass the
    /// exact seek target — used directly in `outputMediaDataWillChange`.
    /// Pass `isRetry: true` for a tolerant-seek retry; suppresses
    /// `onSeekStuck` on expiry to break recovery loops.
    func forceRefresh(for seekTime: CMTime, isRetry: Bool = false) {
        mediaDataRearmCount = 0
        pendingSeekTime = seekTime
        forceRefreshDeadline = CACurrentMediaTime() + 0.6
        forceWindowFailCount = 0
        forceWindowIsRetry = isRetry
        videoOutput?.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
    }

    /// Synchronously attempts to pull a frame at `time` and push it into
    /// the Flutter texture. Returns `true` if a real `CVPixelBuffer` was
    /// delivered (which fires `onFirstFrame` on the first successful
    /// call) and resets the output's retry/refresh bookkeeping like a
    /// regular delivery would. Used by `safePreroll` to flip
    /// `DivineVideoPlayerInstance.firstFrameRendered` only when the
    /// texture actually has a buffer — otherwise Flutter would render
    /// the texture's initial empty state (black) until the async
    /// display-link path delivers one.
    @discardableResult
    func tryPullFrameNow(at time: CMTime) -> Bool {
        guard let output = videoOutput else { return false }
        guard let pixelBuffer = output.copyPixelBuffer(
            forItemTime: time,
            itemTimeForDisplay: nil
        ) else {
            return false
        }
        pendingSeekTime = .invalid
        forceRefreshDeadline = 0
        forceWindowFailCount = 0
        mediaDataRearmCount = 0
        deliverFrame(pixelBuffer)
        return true
    }

    // MARK: - AVPlayerItemOutputPullDelegate

    /// Called after a seek flushes the output queue.
    func outputSequenceWasFlushed(_ output: AVPlayerItemOutput) {
        mediaDataRearmCount = 0
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
        let pb = videoOutput.copyPixelBuffer(
            forItemTime: targetTime,
            itemTimeForDisplay: nil
        )
        guard let pixelBuffer = pb else {
            mediaDataRearmCount += 1
            if mediaDataRearmCount < VideoTextureOutput.maxMediaDataRearmCount {
                videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: 0)
            }
            return
        }
        mediaDataRearmCount = 0
        pendingSeekTime = .invalid
        forceRefreshDeadline = 0
        forceWindowFailCount = 0
        deliverFrame(pixelBuffer)
    }

    /// Cleans up display link and unregisters the texture.
    func dispose() {
        stopDisplayLink()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        registry.unregisterTexture(textureId)
        videoOutput = nil
        latestPixelBuffer = nil
        onFirstFrame = nil
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        os_unfair_lock_lock(&pixelBufferLock)
        let pixelBuffer = latestPixelBuffer
        os_unfair_lock_unlock(&pixelBufferLock)
        guard let pixelBuffer else { return nil }
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
        os_unfair_lock_lock(&pixelBufferLock)
        latestPixelBuffer = pixelBuffer
        os_unfair_lock_unlock(&pixelBufferLock)
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

        // Skip `hasNewPixelBuffer(forItemTime:)` and just attempt the
        // copy. With an `AVMutableComposition` + `AVVideoComposition`,
        // the predicate returns `false` indefinitely on some HEVC
        // sources even while the player is actively decoding — audio
        // continues, time advances, but the texture stays on the first
        // frame until a flush (loop restart) clears the deadlock.
        // `copyPixelBuffer(forItemTime:)` is cheap when no new frame
        // is ready (returns `nil`), so polling it on every display-link
        // tick costs only the call itself.
        if let pixelBuffer = output.copyPixelBuffer(
            forItemTime: itemTime,
            itemTimeForDisplay: nil
        ) {
            deliverFrame(pixelBuffer)
        }
    }
}
