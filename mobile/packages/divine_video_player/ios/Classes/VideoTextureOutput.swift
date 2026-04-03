import AVFoundation
import Flutter

/// Bridges an `AVPlayer` to Flutter's texture system.
///
/// Uses `AVPlayerItemVideoOutput` to pull `CVPixelBuffer` frames from
/// the player and exposes them via the `FlutterTexture` protocol.
/// A `CADisplayLink` drives the frame polling loop.
final class VideoTextureOutput: NSObject, FlutterTexture {

    private let registry: FlutterTextureRegistry
    private var onFirstFrame: (() -> Void)?

    /// The ID registered with Flutter's texture registry.
    private(set) var textureId: Int64 = 0

    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var latestPixelBuffer: CVPixelBuffer?
    private var hasDeliveredFirstFrame = false
    private weak var player: AVPlayer?

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

    /// Attaches the display-link driven polling loop to the player.
    /// Call once after the player is created.
    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startDisplayLink()
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

    @objc private func onDisplayLink() {
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
