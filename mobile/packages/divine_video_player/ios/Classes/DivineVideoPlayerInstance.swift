import AVFoundation
import Flutter

/// Wraps a single AVPlayer fed by an `AVMutableComposition` that
/// stitches multiple clips into a seamless timeline.
///
/// Communicates with Dart via per-player MethodChannel/EventChannel.
final class DivineVideoPlayerInstance: NSObject, FlutterStreamHandler {

    private let playerId: Int
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel

    private var player: AVPlayer?
    private var eventSink: FlutterEventSink?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    // MARK: - Texture rendering

    /// Non-nil when the player renders into a Flutter texture instead of
    /// a platform view.
    private var textureOutput: VideoTextureOutput?

    /// Invisible player layer added to the Flutter root view.
    ///
    /// On iOS, `AVPlayerItemVideoOutput` refuses to deliver decoded
    /// pixel buffers for many streams (HLS, FairPlay, and even some
    /// progressive MP4s) unless an `AVPlayerLayer` is attached to the
    /// player.  The layer does not need to be visible — its mere
    /// presence tells AVFoundation that the app intends to display
    /// the video, which disables the pixel-buffer copy-protection.
    ///
    /// See: https://github.com/flutter/flutter/issues/111457
    private var workaroundPlayerLayer: AVPlayerLayer?

    /// Offsets of each clip on the global timeline (seconds).
    private var clipOffsets: [Double] = []
    /// Clip durations on the global timeline (seconds).
    private var clipDurations: [Double] = []
    private var clipCount: Int = 0
    private var totalDuration: Double = 0
    private var isLooping: Bool = false
    private var volume: Double = 1.0
    private var speed: Double = 1.0
    private var currentStatus: String = "idle"
    private var errorMessage: String?
    private var firstFrameRendered: Bool = false
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0

    /// Audio overlay manager for synchronized audio tracks.
    private let audioOverlayManager = AudioOverlayManager()

    init(messenger: FlutterBinaryMessenger, playerId: Int) {
        self.playerId = playerId

        methodChannel = FlutterMethodChannel(
            name: "divine_video_player/player_\(playerId)",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "divine_video_player/player_\(playerId)/events",
            binaryMessenger: messenger
        )

        super.init()

        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        eventChannel.setStreamHandler(self)
    }

    /// Enables texture-based rendering for this player.
    ///
    /// Must be called before any clips are loaded. Returns the texture
    /// ID that Dart should pass to the `Texture` widget.
    func enableTextureOutput(registry: FlutterTextureRegistry) -> Int64 {
        let output = VideoTextureOutput(registry: registry) { [weak self] in
            guard let self, !self.firstFrameRendered else { return }
            self.firstFrameRendered = true
            self.sendStateUpdate()
        }
        textureOutput = output
        return output.textureId
    }

    // MARK: - MethodChannel handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setClips":
            handleSetClips(call, result: result)
        case "play":
            player?.play()
            player?.rate = Float(speed)
            audioOverlayManager.resumeActive(speed: speed)
            textureOutput?.setPlaying(true)
            result(nil)
        case "pause":
            player?.pause()
            audioOverlayManager.pauseAndDeactivateAll()
            textureOutput?.setPlaying(false)
            result(nil)
        case "stop":
            handleStop(result: result)
        case "seekTo":
            handleSeekTo(call, result: result)
        case "setVolume":
            handleSetVolume(call, result: result)
        case "setPlaybackSpeed":
            handleSetPlaybackSpeed(call, result: result)
        case "setLooping":
            handleSetLooping(call, result: result)
        case "jumpToClip":
            handleJumpToClip(call, result: result)
        case "setAudioTracks":
            handleSetAudioTracks(call, result: result)
        case "removeAllAudioTracks":
            handleRemoveAllAudioTracks(result: result)
        case "setAudioTrackVolume":
            handleSetAudioTrackVolume(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Clip composition

    private func handleSetClips(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let clipsRaw = args["clips"] as? [[String: Any]]
        else {
            result(
                FlutterError(code: "INVALID_ARGS", message: "clips required", details: nil)
            )
            return
        }

        // Build the composition asynchronously.
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result_ = try await self.buildComposition(
                    from: clipsRaw)
                let composition = result_.composition
                let videoTrack = result_.videoTrack
                let transform = result_.transform
                self.clipOffsets = result_.offsets
                self.clipDurations = result_.durations
                self.clipCount = clipsRaw.count
                self.totalDuration = result_.offsets.last.map {
                    $0 + (result_.durations.last ?? 0)
                } ?? 0
                self.firstFrameRendered = false

                let playerItem = AVPlayerItem(asset: composition)

                // Only apply a video composition when the source
                // track has a non-identity transform (e.g. a rotation).
                // Skipping the composition for HLS and identity-
                // transform progressives avoids AVFoundation errors
                // on streams that do not support AVVideoComposition.
                if !transform.isIdentity {
                    let autoVC = AVVideoComposition(
                        propertiesOf: composition
                    )
                    let naturalSize = result_.sourceNaturalSize
                    let transformedRect = CGRect(
                        origin: .zero, size: naturalSize
                    ).applying(transform)
                    let correctedRenderSize = CGSize(
                        width: abs(transformedRect.size.width),
                        height: abs(transformedRect.size.height)
                    )

                    let fixedVC = AVMutableVideoComposition()
                    fixedVC.renderSize = correctedRenderSize
                    fixedVC.frameDuration = autoVC.frameDuration
                    fixedVC.instructions = autoVC.instructions
                    fixedVC.sourceTrackIDForFrameTiming = videoTrack.trackID
                    playerItem.videoComposition = fixedVC
                }
                self.textureOutput?.attach(to: playerItem)

                // Reset dimensions so stale values from the previous video
                // are not reported before the new track loads.
                self.videoWidth = 0
                self.videoHeight = 0

                if let existing = self.player {
                    existing.replaceCurrentItem(with: playerItem)
                    await existing.seek(to: .zero)
                } else {
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    self.player = newPlayer
                    self.textureOutput?.attachPlayer(newPlayer)
                    self.attachWorkaroundPlayerLayer(to: newPlayer)
                    self.addTimeObserver()
                }

                // (Re-)observe the NEW player item's status so
                // updateVideoSize fires for every clip change, not just
                // the first.
                self.observeStatus()

                self.observeEnd(for: self.player!.currentItem!)
                self.currentStatus = "ready"
                self.sendStateUpdate()
                result(nil)
            } catch {
                self.currentStatus = "error"
                self.errorMessage = error.localizedDescription
                self.sendStateUpdate()
                result(
                    FlutterError(
                        code: "COMPOSITION_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            }
        }
    }

    /// Builds an AVMutableComposition that stitches all clips into a
    /// single continuous timeline.
    private func buildComposition(
        from clipsRaw: [[String: Any]]
    ) async throws -> (
        composition: AVMutableComposition,
        videoTrack: AVMutableCompositionTrack,
        offsets: [Double],
        durations: [Double],
        transform: CGAffineTransform,
        sourceNaturalSize: CGSize
    ) {
        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw CompositionError.cannotCreateTrack
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var insertTime = CMTime.zero
        var offsets: [Double] = []
        var durations: [Double] = []

        for clipMap in clipsRaw {
            guard let uri = clipMap["uri"] as? String else { continue }
            let startMs = (clipMap["startMs"] as? NSNumber)?.int64Value ?? 0
            let endMs = clipMap["endMs"] as? NSNumber

            let url: URL
            if uri.hasPrefix("/") {
                url = URL(fileURLWithPath: uri)
            } else if let parsed = URL(string: uri) {
                url = parsed
            } else {
                continue
            }

            let asset = AVURLAsset(url: url)

            // Load duration and tracks.
            let assetDuration = try await asset.load(.duration)
            let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
            let assetAudioTracks = try await asset.loadTracks(withMediaType: .audio)

            guard let sourceVideoTrack = assetVideoTracks.first else { continue }

            let startTime = CMTime(value: startMs, timescale: 1000)
            let endTime: CMTime
            if let endMs {
                endTime = CMTime(value: endMs.int64Value, timescale: 1000)
            } else {
                endTime = assetDuration
            }
            let timeRange = CMTimeRange(start: startTime, end: endTime)

            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)

            if let sourceAudioTrack = assetAudioTracks.first {
                try audioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
            }

            let clipDuration = CMTimeSubtract(endTime, startTime)
            offsets.append(CMTimeGetSeconds(insertTime))
            durations.append(CMTimeGetSeconds(clipDuration))
            insertTime = CMTimeAdd(insertTime, clipDuration)
        }

        // Load the preferredTransform and naturalSize from the first
        // source track. Set preferredTransform on the composition track
        // so AVVideoComposition(propertiesOf:) generates correct layer
        // instructions. The caller will fix the renderSize separately.
        var transform = CGAffineTransform.identity
        var sourceNaturalSize = CGSize.zero
        if let firstClipUri = clipsRaw.first?["uri"] as? String {
            let firstURL: URL
            if firstClipUri.hasPrefix("/") {
                firstURL = URL(fileURLWithPath: firstClipUri)
            } else {
                firstURL = URL(string: firstClipUri)!
            }
            let firstAsset = AVURLAsset(url: firstURL)
            if let firstTrack = try? await firstAsset.loadTracks(withMediaType: .video).first {
                transform = try await firstTrack.load(.preferredTransform)
                sourceNaturalSize = try await firstTrack.load(.naturalSize)
                videoTrack.preferredTransform = transform
            }
        }

        return (composition, videoTrack, offsets, durations, transform, sourceNaturalSize)
    }

    // MARK: - Seek

    private func handleSeekTo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let positionMs = args["positionMs"] as? Int
        else {
            result(nil)
            return
        }
        let time = CMTime(value: Int64(positionMs), timescale: 1000)
        let previousTime = player?.currentTime()
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.syncAudioOverlays()
            if let prev = previousTime, prev != time {
                self?.textureOutput?.expectFrame()
            }
            result(nil)
        }
    }

    // MARK: - Volume / Speed / Looping

    private func handleSetVolume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let vol = args["volume"] as? Double
        else {
            result(nil)
            return
        }
        volume = vol
        player?.volume = Float(vol)
        result(nil)
    }

    private func handleSetPlaybackSpeed(_ call: FlutterMethodCall, result: @escaping FlutterResult)
    {
        guard let args = call.arguments as? [String: Any],
            let spd = args["speed"] as? Double
        else {
            result(nil)
            return
        }
        speed = spd
        player?.rate = Float(spd)
        audioOverlayManager.setSpeed(spd)
        result(nil)
    }

    private func handleSetLooping(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let loop = args["looping"] as? Bool
        else {
            result(nil)
            return
        }
        isLooping = loop
        result(nil)
    }

    private func handleJumpToClip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let index = args["index"] as? Int,
            index >= 0, index < clipOffsets.count
        else {
            result(nil)
            return
        }
        let targetTime = CMTime(seconds: clipOffsets[index], preferredTimescale: 600)
        let previousTime = player?.currentTime()
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) {
            [weak self] _ in
            self?.syncAudioOverlays()
            if let prev = previousTime, prev != targetTime {
                self?.textureOutput?.expectFrame()
            }
            result(nil)
        }
    }

    // MARK: - Stop

    private func handleStop(result: @escaping FlutterResult) {
        audioOverlayManager.pauseAndDeactivateAll()
        textureOutput?.setPlaying(false)
        // Pause and clear media so the surface goes blank.
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        clipOffsets = []
        clipDurations = []
        clipCount = 0
        totalDuration = 0
        firstFrameRendered = false
        currentStatus = "idle"
        sendStateUpdate()
        result(nil)
    }

    // MARK: - Audio overlay tracks

    private func handleSetAudioTracks(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
            let tracksRaw = args["tracks"] as? [[String: Any]]
        else {
            result(
                FlutterError(code: "INVALID_ARGS", message: "tracks list required", details: nil))
            return
        }
        audioOverlayManager.setTracks(from: tracksRaw)
        syncAudioOverlays()
        result(nil)
    }

    private func handleRemoveAllAudioTracks(result: @escaping FlutterResult) {
        audioOverlayManager.disposeAll()
        result(nil)
    }

    private func handleSetAudioTrackVolume(
        _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any],
            let index = args["index"] as? Int,
            let vol = args["volume"] as? Double
        else {
            result(nil)
            return
        }
        audioOverlayManager.setTrackVolume(at: index, volume: Float(vol))
        result(nil)
    }

    /// Syncs audio overlays to the current global video position.
    private func syncAudioOverlays() {
        guard let player else { return }
        audioOverlayManager.update(
            videoPositionSec: max(CMTimeGetSeconds(player.currentTime()), 0),
            isPlaying: player.rate > 0,
            speed: speed
        )
    }

    // MARK: - Observers

    private func addTimeObserver() {
        guard let player else { return }
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] _ in
            self?.syncAudioOverlays()
            self?.sendStateUpdate()
        }
    }

    private func observeStatus() {
        statusObservation = player?.currentItem?.observe(
            \.status,
            options: [.new]
        ) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                self?.currentStatus = "ready"
                self?.updateVideoSize(from: item)
            case .failed:
                self?.currentStatus = "error"
                self?.errorMessage = item.error?.localizedDescription
            default:
                break
            }
            self?.sendStateUpdate()
        }
    }

    private func observeEnd(for item: AVPlayerItem) {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    @objc private func playerDidFinish() {
        if isLooping {
            player?.seek(to: .zero)
            player?.play()
            player?.rate = Float(speed)
            syncAudioOverlays()
        } else {
            audioOverlayManager.pauseAndDeactivateAll()
            textureOutput?.setPlaying(false)
            currentStatus = "completed"
            sendStateUpdate()
        }
    }

    // MARK: - State broadcasting

    private func sendStateUpdate() {
        guard let player, let sink = eventSink else { return }

        let currentTime = CMTimeGetSeconds(player.currentTime())
        let positionMs = currentTime.isFinite ? Int(max(currentTime, 0) * 1000) : 0
        let durationMs = totalDuration.isFinite ? Int(totalDuration * 1000) : 0

        // Determine current clip index.
        var clipIndex = 0
        for i in 0..<clipOffsets.count {
            let clipEnd = clipOffsets[i] + clipDurations[i]
            if currentTime < clipEnd + 0.01 {
                clipIndex = i
                break
            }
            clipIndex = i
        }

        let status: String
        if currentStatus == "error" || currentStatus == "completed" {
            status = currentStatus
        } else if player.rate > 0 {
            status = "playing"
        } else if player.currentItem?.isPlaybackBufferEmpty == true {
            status = "buffering"
        } else if currentStatus == "ready" && player.rate == 0 {
            status = "paused"
        } else {
            status = currentStatus
        }

        var map: [String: Any] = [
            "status": status,
            "positionMs": positionMs,
            "durationMs": durationMs,
            "bufferedPositionMs": bufferedPositionMs(for: player),
            "currentClipIndex": clipIndex,
            "clipCount": clipCount,
            "isLooping": isLooping,
            "volume": volume,
            "playbackSpeed": speed,
            "isFirstFrameRendered": firstFrameRendered,
            "videoWidth": videoWidth,
            "videoHeight": videoHeight,
        ]
        if let errorMessage {
            map["errorMessage"] = errorMessage
        }
        sink(map)
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Accessors for view factory

    func getPlayer() -> AVPlayer? { player }

    /// Called by the platform view when `AVPlayerLayer.isReadyForDisplay`
    /// becomes `true`.
    func setFirstFrameRendered() {
        guard !firstFrameRendered else { return }
        firstFrameRendered = true
        sendStateUpdate()
    }

    // MARK: - Video size

    private func updateVideoSize(from item: AVPlayerItem) {
        // When an AVVideoComposition is set on the player item,
        // AVPlayerItemVideoOutput delivers pixel buffers at the
        // composition's renderSize (which already accounts for the
        // preferredTransform). Use that render size directly so the
        // reported dimensions always match the actual texture frames.
        if let vc = item.videoComposition {
            let rs = vc.renderSize
            let w = rs.width
            let h = rs.height
            videoWidth = w.isFinite ? Int(abs(w)) : 0
            videoHeight = h.isFinite ? Int(abs(h)) : 0
            sendStateUpdate()
            return
        }

        // Fallback: no video composition — read from the track directly.
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let track = try? await item.asset.loadTracks(
                withMediaType: .video
            ).first else {
                return
            }
            let (naturalSize, transform) = try await track.load(
                .naturalSize, .preferredTransform
            )
            let size = naturalSize.applying(transform)
            let w = abs(size.width)
            let h = abs(size.height)
            self.videoWidth = w.isFinite ? Int(w) : 0
            self.videoHeight = h.isFinite ? Int(h) : 0
            self.sendStateUpdate()
        }
    }

    // MARK: - Buffered position

    private func bufferedPositionMs(for player: AVPlayer) -> Int {
        guard let item = player.currentItem,
            let range = item.loadedTimeRanges.first?.timeRangeValue
        else {
            return 0
        }
        let bufferedEnd = CMTimeGetSeconds(
            CMTimeAdd(range.start, range.duration)
        )
        return bufferedEnd.isFinite ? Int(max(bufferedEnd, 0) * 1000) : 0
    }

    // MARK: - App Lifecycle

    /// Whether the player was playing before the app went to background.
    private var wasPlayingBeforePause = false

    func onAppBackgrounded() {
        wasPlayingBeforePause = player?.rate ?? 0 > 0
        if wasPlayingBeforePause {
            player?.pause()
            audioOverlayManager.pauseAndDeactivateAll()
            textureOutput?.setPlaying(false)
            sendStateUpdate()
        }
    }

    func onAppForegrounded() {
        if wasPlayingBeforePause {
            player?.play()
            player?.rate = Float(speed)
            audioOverlayManager.resumeActive(speed: speed)
            textureOutput?.setPlaying(true)
            wasPlayingBeforePause = false
            sendStateUpdate()
        }
    }

    // MARK: - Workaround player layer

    /// Attaches an invisible `AVPlayerLayer` to the Flutter root view.
    ///
    /// On iOS, `AVPlayerItemVideoOutput` refuses to deliver decoded
    /// pixel buffers unless an `AVPlayerLayer` is attached to the
    /// player.  The layer is zero-sized and hidden so it never draws;
    /// its only purpose is to convince AVFoundation that the video
    /// surface is "live".
    private func attachWorkaroundPlayerLayer(to player: AVPlayer) {
        guard textureOutput != nil else { return }
        let layer = AVPlayerLayer(player: player)
        layer.frame = .zero
        layer.isHidden = true
        if let rootLayer = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController?.view.layer
        {
            rootLayer.addSublayer(layer)
        }
        workaroundPlayerLayer = layer
    }

    // MARK: - Dispose

    func dispose() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        NotificationCenter.default.removeObserver(self)
        workaroundPlayerLayer?.removeFromSuperlayer()
        workaroundPlayerLayer = nil
        textureOutput?.dispose()
        textureOutput = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        audioOverlayManager.disposeAll()
        eventSink = nil
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
}

// MARK: - Error type

private enum CompositionError: Error, LocalizedError {
    case cannotCreateTrack

    var errorDescription: String? {
        switch self {
        case .cannotCreateTrack:
            return "Failed to create composition track."
        }
    }
}
