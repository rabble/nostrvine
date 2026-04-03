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

    /// Whether the host AVPlayer is currently playing.
    private var isPlaying = false
    /// Set to `true` when a seek or attach happens while paused so the
    /// display-link runs long enough to pull the new frame.
    private var waitingForFrame = false
    /// Desired presentation time returned by the last display-link
    /// callback.  Used with `itemTime(forHostTime:)` for precise
    /// frame selection.
    private var targetTime: CFTimeInterval = 0

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
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ]
        let output = AVPlayerItemVideoOutput(
            pixelBufferAttributes: attrs
        )
        item.add(output)
        videoOutput = output
        hasDeliveredFirstFrame = false
        expectFrame()
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

    // MARK: - Playback state (controls display-link)

    /// Informs the texture output that playback started or stopped.
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        updateDisplayLinkRunning()
    }

    /// Requests exactly one frame pull — used after seek-while-paused
    /// or when a new item is attached so the UI shows the correct
    /// poster frame.
    func expectFrame() {
        waitingForFrame = true
        updateDisplayLinkRunning()
    }

    /// Pauses the display-link when the player is idle **and** no
    /// one-shot frame is outstanding.
    private func updateDisplayLinkRunning() {
        let shouldRun = isPlaying || waitingForFrame
        displayLink?.isPaused = !shouldRun
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
        updateDisplayLinkRunning()
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onDisplayLink(_ link: CADisplayLink) {
        guard let output = videoOutput,
              let player else { return }

        let hostTime = link.targetTimestamp
        let itemTime = output.itemTime(forHostTime: hostTime)
        guard output.hasNewPixelBuffer(forItemTime: itemTime) else { return }

        if let pixelBuffer = output.copyPixelBuffer(
            forItemTime: itemTime,
            itemTimeForDisplay: nil
        ) {
            latestPixelBuffer = pixelBuffer
            registry.textureFrameAvailable(textureId)

            if waitingForFrame {
                waitingForFrame = false
                updateDisplayLinkRunning()
            }

            if !hasDeliveredFirstFrame {
                hasDeliveredFirstFrame = true
                onFirstFrame?()
            }
        }
    }
}
