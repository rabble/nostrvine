import AVFoundation
import FlutterMacOS

/// Bridges an `AVPlayer` to Flutter's texture system on macOS.
///
/// Uses `AVPlayerItemVideoOutput` to pull `CVPixelBuffer` frames from
/// the player and exposes them via the `FlutterTexture` protocol.
/// A timer drives the frame polling loop (macOS has no `CADisplayLink`).
final class VideoTextureOutput: NSObject, FlutterTexture {

    private let registry: FlutterTextureRegistry
    private var onFirstFrame: (() -> Void)?

    /// The ID registered with Flutter's texture registry.
    private(set) var textureId: Int64

    private var videoOutput: AVPlayerItemVideoOutput?
    private var pollTimer: Timer?
    private var latestPixelBuffer: CVPixelBuffer?
    private var hasDeliveredFirstFrame = false
    private weak var player: AVPlayer?

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
        // Remove previous output if any.
        if let old = videoOutput {
            item.remove(old)
        }

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA,
        ]
        let output = AVPlayerItemVideoOutput(
            pixelBufferAttributes: attrs
        )
        item.add(output)
        videoOutput = output
        hasDeliveredFirstFrame = false
    }

    /// Attaches the polling loop to the player.
    /// Call once after the player is created.
    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startPolling()
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
        guard output.hasNewPixelBuffer(forItemTime: itemTime) else { return }

        if let pixelBuffer = output.copyPixelBuffer(
            forItemTime: itemTime,
            itemTimeForDisplay: nil
        ) {
            latestPixelBuffer = pixelBuffer
            registry.textureFrameAvailable(textureId)

            if !hasDeliveredFirstFrame {
                hasDeliveredFirstFrame = true
                onFirstFrame?()
            }
        }
    }
}
