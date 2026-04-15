import AVFoundation
import Flutter
import UIKit

/// Entry point for the divine_video_player plugin on iOS.
///
/// Manages the lifecycle of ``DivineVideoPlayerInstance`` objects and
/// registers the platform view factory for rendering.
public class DivineVideoPlayerPlugin: NSObject, FlutterPlugin {

    private static var registrar: FlutterPluginRegistrar?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Hot restart re-calls register(with:) without disposing the
        // previous engine's players. Clean up zombie players so timers
        // and observers are released.
        PlayerRegistry.shared.disposeAll()

        self.registrar = registrar

        let globalChannel = FlutterMethodChannel(
            name: "divine_video_player",
            binaryMessenger: registrar.messenger()
        )
        let plugin = DivineVideoPlayerPlugin()
        registrar.addMethodCallDelegate(plugin, channel: globalChannel)

        registrar.register(
            DivineVideoPlayerViewFactory(messenger: registrar.messenger()),
            withId: "divine_video_player_view"
        )

        // Observe app lifecycle to pause/resume all players.
        NotificationCenter.default.addObserver(
            plugin,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            plugin,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        PlayerRegistry.shared.forAll { $0.onAppBackgrounded() }
    }

    @objc private func appDidBecomeActive() {
        PlayerRegistry.shared.forAll { $0.onAppForegrounded() }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Methods that require no arguments are handled before the
        // args guard to avoid returning FlutterMethodNotImplemented.
        if call.method == "disposeAll" {
            PlayerRegistry.shared.disposeAll()
            result(nil)
            return
        }

        guard let args = call.arguments as? [String: Any] else {
            result(FlutterMethodNotImplemented)
            return
        }

        switch call.method {
        case "create":
            guard let id = args["id"] as? Int,
                  let registrar = Self.registrar else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS",
                        message: "Missing player id",
                        details: nil
                    )
                )
                return
            }
            // Dispose any existing player with the same ID before
            // creating the new one to avoid leaking zombie players.
            PlayerRegistry.shared.remove(id)?.dispose()

            let instance = DivineVideoPlayerInstance(
                messenger: registrar.messenger(),
                playerId: id
            )
            PlayerRegistry.shared.set(instance, for: id)

            let useTexture = args["useTexture"] as? Bool ?? false
            if useTexture {
                let textureId = instance.enableTextureOutput(
                    registry: registrar.textures()
                )
                result(["textureId": textureId])
            } else {
                result(nil)
            }

        case "dispose":
            guard let id = args["id"] as? Int else {
                result(nil)
                return
            }
            PlayerRegistry.shared.remove(id)?.dispose()
            result(nil)

        case "preload":
            let clips = args["clips"] as? [[String: Any]] ?? []
            Self.handlePreload(clips: clips, result: result)

        case "configureCache":
            let maxSizeBytes = args["maxSizeBytes"] as? Int ?? (500 * 1024 * 1024)
            // 10% of disk budget for in-memory cache, rest on disk.
            let memoryCapacity = maxSizeBytes / 10
            URLCache.shared = URLCache(
                memoryCapacity: memoryCapacity,
                diskCapacity: maxSizeBytes,
                diskPath: "divine_video_cache"
            )
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Preloads video metadata and initial buffer data by loading
    /// `AVURLAsset` properties asynchronously. The OS-level URL cache
    /// retains the fetched data so that a real player starts faster.
    private static func handlePreload(
        clips: [[String: Any]],
        result: @escaping FlutterResult
    ) {
        guard !clips.isEmpty else {
            result(nil)
            return
        }

        let group = DispatchGroup()

        for clipMap in clips {
            guard let uri = clipMap["uri"] as? String else { continue }

            let url: URL
            if uri.hasPrefix("/") {
                url = URL(fileURLWithPath: uri)
            } else if let parsed = URL(string: uri) {
                url = parsed
            } else {
                continue
            }

            group.enter()
            let asset = AVURLAsset(url: url)
            asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            result(nil)
        }
    }
}

/// Global registry so that ``DivineVideoPlayerViewFactory`` can find
/// instances created during the `create` method call.
final class PlayerRegistry {
    static let shared = PlayerRegistry()
    private var players: [Int: DivineVideoPlayerInstance] = [:]
    private init() {}

    func get(_ id: Int) -> DivineVideoPlayerInstance? { players[id] }
    func set(_ instance: DivineVideoPlayerInstance, for id: Int) { players[id] = instance }
    @discardableResult
    func remove(_ id: Int) -> DivineVideoPlayerInstance? {
        let instance = players.removeValue(forKey: id)
        return instance
    }
    func disposeAll() {
        players.values.forEach { $0.dispose() }
        players.removeAll()
    }
    func forAll(_ action: (DivineVideoPlayerInstance) -> Void) {
        players.values.forEach(action)
    }
}
