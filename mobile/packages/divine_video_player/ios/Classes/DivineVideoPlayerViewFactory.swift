import AVFoundation
import Flutter
import UIKit

/// Factory that creates ``DivineVideoPlayerPlatformView`` instances
/// for the Flutter platform view system on iOS.
final class DivineVideoPlayerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let params = args as? [String: Any]
        let playerId = params?["playerId"] as? Int ?? -1
        return DivineVideoPlayerPlatformView(frame: frame, playerId: playerId)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

/// iOS platform view that renders video using ``AVPlayerLayer``.
final class DivineVideoPlayerPlatformView: NSObject, FlutterPlatformView {

    private let containerView: _PlayerContainerView
    private var readyForDisplayObservation: NSKeyValueObservation?
    private weak var playerInstance: DivineVideoPlayerInstance?

    init(frame: CGRect, playerId: Int) {
        containerView = _PlayerContainerView(frame: frame)
        super.init()

        if let instance = PlayerRegistry.shared.get(playerId),
            let player = instance.getPlayer()
        {
            playerInstance = instance
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspect
            containerView.playerLayer = layer
            containerView.layer.addSublayer(layer)

            readyForDisplayObservation = layer.observe(
                \.isReadyForDisplay,
                options: [.new]
            ) { [weak self] avLayer, _ in
                if avLayer.isReadyForDisplay {
                    self?.playerInstance?.setFirstFrameRendered()
                    self?.readyForDisplayObservation?.invalidate()
                    self?.readyForDisplayObservation = nil
                }
            }
        }
    }

    func view() -> UIView { containerView }
}

/// Container view that keeps the ``AVPlayerLayer`` sized to its bounds.
private final class _PlayerContainerView: UIView {

    var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
