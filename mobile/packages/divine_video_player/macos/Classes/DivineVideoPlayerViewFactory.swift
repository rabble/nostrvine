import AVFoundation
import Cocoa
import FlutterMacOS

/// Factory that creates ``DivineVideoPlayerPlatformView`` instances
/// for the Flutter platform view system on macOS.
final class DivineVideoPlayerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withViewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> NSView {
        let params = args as? [String: Any]
        let playerId = params?["playerId"] as? Int ?? -1
        return DivineVideoPlayerNSView(playerId: playerId)
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

/// macOS view that renders video using ``AVPlayerLayer``.
final class DivineVideoPlayerNSView: NSView {

    private var playerLayer: AVPlayerLayer?
    private var readyForDisplayObservation: NSKeyValueObservation?
    private weak var playerInstance: DivineVideoPlayerInstance?

    init(playerId: Int) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        if let instance = MacPlayerRegistry.shared.get(playerId),
           let player = instance.getPlayer() {
            playerInstance = instance
            let avLayer = AVPlayerLayer(player: player)
            avLayer.videoGravity = .resizeAspect
            layer?.addSublayer(avLayer)
            playerLayer = avLayer

            readyForDisplayObservation = avLayer.observe(
                \.isReadyForDisplay,
                options: [.new]
            ) { [weak self] layer, _ in
                if layer.isReadyForDisplay {
                    self?.playerInstance?.setFirstFrameRendered()
                    self?.readyForDisplayObservation?.invalidate()
                    self?.readyForDisplayObservation = nil
                }
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
}
