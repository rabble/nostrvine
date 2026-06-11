import AVFoundation
#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import Cocoa
import FlutterMacOS
#endif

/// Factory that creates the native player view for the Flutter platform
/// view system. Renders an ``AVPlayerLayer`` inside a `UIView` on iOS and
/// an `NSView` on macOS.
final class DivineVideoPlayerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    #if os(iOS)
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
    #elseif os(macOS)
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
    #endif
}

#if os(iOS)
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
#elseif os(macOS)
/// macOS view that renders video using ``AVPlayerLayer``.
final class DivineVideoPlayerNSView: NSView {

    private var playerLayer: AVPlayerLayer?
    private var readyForDisplayObservation: NSKeyValueObservation?
    private weak var playerInstance: DivineVideoPlayerInstance?

    init(playerId: Int) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        if let instance = PlayerRegistry.shared.get(playerId),
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
#endif
