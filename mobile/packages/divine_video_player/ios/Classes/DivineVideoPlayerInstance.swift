import AVFoundation
import Flutter

/// Wraps a single AVQueuePlayer fed by an `AVMutableComposition` that
/// stitches multiple clips into a seamless timeline.
///
/// Communicates with Dart via per-player MethodChannel/EventChannel.
final class DivineVideoPlayerInstance: NSObject, FlutterStreamHandler {

    private let playerId: Int
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel

    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var templateItem: AVPlayerItem?
    private var eventSink: FlutterEventSink?
    private var timeObserver: Any?
    private var currentItemObservation: NSKeyValueObservation?
    private var statusObservation: NSKeyValueObservation?
    /// One-shot KVO that defers `preroll(atRate:)` until `player.status`
    /// is `.readyToPlay`; calling earlier throws `NSInvalidArgumentException`.
    private var pendingPrerollObservation: NSKeyValueObservation?

    // MARK: - Texture rendering

    /// Non-nil when the player renders into a Flutter texture instead of
    /// a platform view.
    private var textureOutput: VideoTextureOutput?

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
        // Recovery for compositor dead zones: if the 600 ms force window
        // delivers no frame, the seek landed on a time with no renderable
        // frame (e.g. exact boundary between composition segments). Retry
        // with a small tolerance to snap to the nearest decodable frame.
        output.onSeekStuck = { [weak self] stuckTime in
            guard let self else { return }
            self.player?.seek(
                to: stuckTime,
                toleranceBefore: CMTime(value: 1, timescale: 10),
                toleranceAfter: CMTime(value: 1, timescale: 10)
            ) { [weak self] _ in
                guard let self else { return }
                let actualTime = self.player?.currentTime() ?? stuckTime
                self.textureOutput?.forceRefresh(for: actualTime, isRetry: true)
                self.safePreroll(at: actualTime)
            }
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
            result(nil)
        case "pause":
            player?.pause()
            audioOverlayManager.pauseAndDeactivateAll()
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
                let (composition, videoComposition, offsets, durations, audioMix) = try await self.buildComposition(
                    from: clipsRaw)
                self.clipOffsets = offsets
                self.clipDurations = durations
                self.clipCount = offsets.count
                self.totalDuration = offsets.last.map { $0 + (durations.last ?? 0) } ?? 0
                self.firstFrameRendered = false

                let playerItem = AVPlayerItem(asset: composition)
                // Prevent pitch distortion when clips play at a speed
                // other than 1×. .spectral (phase vocoder) preserves
                // pitch across the full speed range.
                playerItem.audioTimePitchAlgorithm = .spectral
                if let videoComposition {
                    playerItem.videoComposition = videoComposition
                }
                if let audioMix { playerItem.audioMix = audioMix }
                guard (videoComposition?.renderSize ?? composition.naturalSize).isPositive else {
                    throw CompositionError.invalidRenderSize
                }
                self.templateItem = playerItem

                let startPositionMs = (args["startPositionMs"] as? NSNumber)?.int64Value ?? 0
                // Many encoded videos in the feed have 1 black leading
                // frame at exactly time 0 — produced by the encoder
                // before the first real I-frame. Landing on that frame
                // is what causes the "black until play" bug for
                // preloaded items and the flash on loop restart.
                //
                // Diagnosed via composition.tracks segment.timeMapping
                // inspection (#3242): segment.target.start == 0 and
                // segment.source.start == 0, so this is encoder
                // pre-roll inside the source asset, NOT a Composition
                // gap. The fix is therefore a small forward seek when
                // no explicit start position was requested.
                //
                // 33ms ≈ 1 frame @ 30fps; videos in the feed are
                // ~29.9fps. `toleranceAfter` lets AVPlayer snap to the
                // next sync sample so we land on real content.
                //
                // Backend-side fix (proper solution): trim leading
                // black frames during transcoding. Tracked separately.
                let leadingBlackFrameSkip = CMTime(value: 1, timescale: 30)
                let startTime: CMTime
                if startPositionMs > 0 {
                    startTime = CMTime(value: startPositionMs, timescale: 1000)
                } else {
                    startTime = leadingBlackFrameSkip
                }

                if let existing = self.player {
                    self.configureQueue(with: playerItem)
                    await existing.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    self.textureOutput?.forceRefresh(for: startTime)
                } else {
                    let newPlayer = AVQueuePlayer()
                    self.player = newPlayer
                    self.textureOutput?.attachPlayer(newPlayer)
                    self.addTimeObserver()
                    self.observeCurrentItem()
                    self.configureQueue(with: playerItem)
                    if startPositionMs > 0 {
                        await newPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                    self.textureOutput?.forceRefresh(for: startTime)
                }

                // Preroll so the texture has a real frame at startTime
                // even while paused. Deferred via safePreroll because
                // preroll throws before status reaches .readyToPlay.
                self.safePreroll(at: startTime)

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
    ) async throws -> (AVMutableComposition, AVVideoComposition?, [Double], [Double], AVMutableAudioMix?) {
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
        var videoComposition: AVMutableVideoComposition?
        var layerInstruction: AVMutableVideoCompositionLayerInstruction?
        var clipVolumes: [Float] = []

        for clipMap in clipsRaw {
            guard let uri = clipMap["uri"] as? String else { continue }
            let startMs = (clipMap["startMs"] as? NSNumber)?.int64Value ?? 0
            let endMs = clipMap["endMs"] as? NSNumber
            let clipVol = (clipMap["volume"] as? NSNumber)?.floatValue ?? 1.0
            let clipSpeed = (clipMap["playbackSpeed"] as? NSNumber)?.doubleValue ?? 1.0

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
            let (naturalSize, transform) = try await sourceVideoTrack.load(
                .naturalSize, .preferredTransform
            )
            let displaySize = naturalSize.applying(transform).absoluteSize
            guard displaySize.isPositive else { continue }
            let standardizedTransform = transform.standardized(for: naturalSize)

            let startTime = CMTime(value: startMs, timescale: 1000)
            let endTime: CMTime
            if let endMs {
                endTime = CMTime(value: endMs.int64Value, timescale: 1000)
            } else {
                endTime = assetDuration
            }
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            let clipDuration = CMTimeSubtract(endTime, startTime)
            guard CMTimeCompare(clipDuration, .zero) > 0 else { continue }

            if offsets.isEmpty {
                composition.naturalSize = displaySize
                videoTrack.preferredTransform = transform
                if !standardizedTransform.isEffectivelyIdentity {
                    let instruction = AVMutableVideoCompositionLayerInstruction(
                        assetTrack: videoTrack
                    )
                    let mutableVideoComposition = AVMutableVideoComposition()
                    mutableVideoComposition.renderSize = displaySize
                    mutableVideoComposition.sourceTrackIDForFrameTiming = videoTrack.trackID
                    if sourceVideoTrack.minFrameDuration.isValid {
                        mutableVideoComposition.frameDuration = sourceVideoTrack.minFrameDuration
                    } else {
                        mutableVideoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                    }
                    layerInstruction = instruction
                    videoComposition = mutableVideoComposition
                }
            }
            layerInstruction?.setTransform(standardizedTransform, at: insertTime)

            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)

            if let sourceAudioTrack = assetAudioTracks.first {
                try audioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
            }

            // Scale the just-inserted segment to achieve per-clip playback speed.
            // A speed of 2.0 halves the presentation duration; 0.5 doubles it.
            let scaledDuration: CMTime
            if clipSpeed != 1.0, clipSpeed > 0 {
                let scaledSeconds = CMTimeGetSeconds(clipDuration) / clipSpeed
                scaledDuration = CMTime(seconds: scaledSeconds, preferredTimescale: 600)
                let insertedRange = CMTimeRange(start: insertTime, duration: clipDuration)
                composition.scaleTimeRange(insertedRange, toDuration: scaledDuration)
            } else {
                scaledDuration = clipDuration
            }

            offsets.append(CMTimeGetSeconds(insertTime))
            durations.append(CMTimeGetSeconds(scaledDuration))
            clipVolumes.append(clipVol)
            insertTime = CMTimeAdd(insertTime, scaledDuration)
        }

        guard !offsets.isEmpty else {
            throw CompositionError.noPlayableVideoTracks
        }
        if let videoComposition, let layerInstruction {
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: insertTime)
            instruction.layerInstructions = [layerInstruction]
            videoComposition.instructions = [instruction]
        }

        // Build an AVAudioMix that applies per-clip volume using time ranges on
        // the single composition audio track. AVQueuePlayer.volume multiplies on
        // top automatically, so 0.0 here = muted for that clip regardless of the
        // global volume.
        var audioMix: AVMutableAudioMix?
        if let audioTrack {
            let params = AVMutableAudioMixInputParameters(track: audioTrack)
            var t = CMTime.zero
            for (i, dur) in durations.enumerated() {
                let clipDuration = CMTime(seconds: dur, preferredTimescale: 600)
                let range = CMTimeRange(start: t, duration: clipDuration)
                let vol = clipVolumes[i]
                params.setVolumeRamp(
                    fromStartVolume: vol,
                    toEndVolume: vol,
                    timeRange: range
                )
                t = CMTimeAdd(t, clipDuration)
            }
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            audioMix = mix
        }

        return (composition, videoComposition, offsets, durations, audioMix)
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
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else {
                result(nil)
                return
            }
            self.textureOutput?.forceRefresh(for: time)
            self.syncAudioOverlays()
            // Preroll primes the output pipeline at the new position;
            // without it a paused player near a clip boundary keeps
            // returning the pre-seek buffer until play() is pressed.
            self.safePreroll(at: time)
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
        rebuildQueueForLoopingChange()
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
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) {
            [weak self] _ in
            guard let self else {
                result(nil)
                return
            }
            self.textureOutput?.forceRefresh(for: targetTime)
            self.syncAudioOverlays()
            // Same stuck-frame guard as handleSeekTo: a paused player
            // landing on a clip boundary keeps returning the pre-seek
            // buffer until preroll primes the output pipeline.
            self.safePreroll(at: targetTime)
            result(nil)
        }
    }

    // MARK: - Stop

    private func handleStop(result: @escaping FlutterResult) {
        audioOverlayManager.pauseAndDeactivateAll()
        // Pause and clear media so the surface goes blank.
        player?.pause()
        playerLooper = nil
        templateItem = nil
        player?.removeAllItems()
        clipOffsets = []
        clipDurations = []
        clipCount = 0
        totalDuration = 0
        firstFrameRendered = false
        currentStatus = "idle"
        errorMessage = nil  // clear stale error so sendStateUpdate never emits
                            // status="error" after media has been released.
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

    private func configureQueue(with item: AVPlayerItem) {
        guard let player else { return }
        playerLooper = nil
        player.removeAllItems()
        if isLooping {
            playerLooper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
        }
        attachCurrentItemOutputs()
    }

    private func rebuildQueueForLoopingChange() {
        guard let player, let item = templateItem else { return }
        let resumeTime = player.currentTime()
        let shouldResume = player.rate > 0
        currentStatus = "ready"
        configureQueue(with: item)
        player.seek(to: resumeTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            self.textureOutput?.forceRefresh(for: resumeTime)
            self.syncAudioOverlays()
            if shouldResume {
                self.player?.play()
                self.player?.rate = Float(self.speed)
                self.audioOverlayManager.resumeActive(speed: self.speed)
            }
        }
    }

    /// Calls `AVPlayer.preroll(atRate:)` only when the player is ready;
    /// otherwise defers via a one-shot KVO on `status`. No-op while
    /// `player.rate != 0` (preroll is only useful when paused).
    ///
    /// Must be called on the main thread — `pendingPrerollObservation`
    /// is mutated here without synchronization. All current callers
    /// (setClips Task @MainActor, MethodChannel callbacks, seek
    /// completion handlers) are already main-queue.
    private func safePreroll(at time: CMTime) {
        assert(Thread.isMainThread, "safePreroll must be called on the main thread")
        guard let player = self.player else { return }
        guard player.rate == 0 else { return }
        if player.status == .readyToPlay {
            player.preroll(atRate: 1.0) { [weak self] prerolled in
                guard prerolled else { return }
                // `preroll(atRate:)` completion runs on an unspecified
                // internal queue. Hop to main before touching
                // `currentItem` / `step(byCount:)` / `textureOutput`.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.nudgeOutputQueue()
                    self.textureOutput?.forceRefresh(for: time)
                    // `step(byCount:)` enqueues into the player's
                    // internal pipeline and the resulting frame is not
                    // available on `copyPixelBuffer` until the next
                    // runloop iteration. Defer the synchronous pull
                    // attempt one tick so it has a chance to succeed —
                    // and only flip `firstFrameRendered` (via
                    // `deliverFrame`→`onFirstFrame`) when a real
                    // `CVPixelBuffer` is actually in the texture.
                    // Otherwise Flutter would hide the loader over an
                    // empty texture and render one frame of black
                    // before the display-link path catches up.
                    DispatchQueue.main.async { [weak self] in
                        self?.textureOutput?.tryPullFrameNow(at: time)
                    }
                }
            }
            return
        }
        pendingPrerollObservation?.invalidate()
        pendingPrerollObservation = player.observe(
            \.status,
            options: [.new]
        ) { [weak self] obsPlayer, _ in
            guard obsPlayer.status == .readyToPlay else { return }
            // KVO callbacks fire on whichever queue mutated the
            // observed key. `pendingPrerollObservation` mutation and
            // the inner preroll must happen on main.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingPrerollObservation?.invalidate()
                self.pendingPrerollObservation = nil
                guard obsPlayer.rate == 0 else { return }
                obsPlayer.preroll(atRate: 1.0) { [weak self] prerolled in
                    guard prerolled else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.nudgeOutputQueue()
                        self.textureOutput?.forceRefresh(for: time)
                        // See sibling branch above: defer the pull one
                        // runloop tick so `step(byCount:)` has produced
                        // a frame, and only mark the controller as
                        // ready when a real `CVPixelBuffer` lands in
                        // the Flutter texture.
                        DispatchQueue.main.async { [weak self] in
                            self?.textureOutput?.tryPullFrameNow(at: time)
                        }
                    }
                }
            }
        }
    }

    /// Forces `AVPlayerItemVideoOutput` to populate its frame queue while
    /// the player is paused.
    ///
    /// `preroll(atRate:)` warms the decoder buffer but does not push a
    /// frame into the video-output queue — that queue only fills when the
    /// player's timebase advances. On a paused player at rate=0, the
    /// timebase never advances, so `copyPixelBuffer(forItemTime:)` keeps
    /// returning `nil` and the Flutter `Texture` stays black until
    /// `play()` is called.
    ///
    /// `step(byCount: 1)` followed by `step(byCount: -1)` advances the
    /// timebase by one frame and back, netting to the same position but
    /// causing the output to enqueue a frame in the process — the only
    /// reliable way to produce the first paused frame on iOS.
    private func nudgeOutputQueue() {
        guard let item = player?.currentItem, item.canStepForward else { return }
        item.step(byCount: 1)
        if item.canStepBackward {
            item.step(byCount: -1)
        }
    }

    private func observeCurrentItem() {
        currentItemObservation = player?.observe(
            \.currentItem,
            options: [.new]
        ) { [weak self] _, _ in
            self?.attachCurrentItemOutputs()
        }
        attachCurrentItemOutputs()
    }

    private func attachCurrentItemOutputs() {
        guard let item = player?.currentItem else { return }
        textureOutput?.attach(to: item)
        observeStatus(for: item)
        observeEnd(for: item)
    }

    private func observeStatus(for item: AVPlayerItem) {
        statusObservation?.invalidate()
        statusObservation = item.observe(
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
        guard !isLooping else { return }
        audioOverlayManager.pauseAndDeactivateAll()
        currentStatus = "completed"
        sendStateUpdate()
    }

    // MARK: - State broadcasting

    private func sendStateUpdate() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.sendStateUpdate()
            }
            return
        }
        sendStateUpdateOnMain()
    }

    private func sendStateUpdateOnMain() {
        guard let player, let sink = eventSink else { return }

        let currentTime = CMTimeGetSeconds(player.currentTime())
        let positionMs = Int(max(currentTime, 0) * 1000)
        let durationMs = Int(totalDuration * 1000)

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
        if let errorCode = resolvedErrorCode() {
            map["errorCode"] = errorCode
        }
        sink(map)
    }

    /// Maps the current player error to a canonical error code string that
    /// matches the values defined in `NativePlayerErrorCode` on the Dart side.
    private func resolvedErrorCode() -> String? {
        let nsError: NSError?
        if let itemError = player?.currentItem?.error as NSError? {
            nsError = itemError
        } else if currentStatus == "error" {
            nsError = nil
        } else {
            return nil
        }

        guard let err = nsError else { return currentStatus == "error" ? "unknown" : nil }

        // HTTP errors carried inside AVFoundation errors.
        if let httpResponse = err.userInfo["NSURLErrorFailingURLResponseErrorKey"] as? HTTPURLResponse {
            return httpResponse.statusCode >= 500 ? "http_server_error" : "http_client_error"
        }

        switch (err.domain, err.code) {
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet),
             (NSURLErrorDomain, NSURLErrorNetworkConnectionLost),
             (NSURLErrorDomain, NSURLErrorDataNotAllowed):
            return "network_error"
        case (NSURLErrorDomain, NSURLErrorTimedOut):
            return "timeout"
        default:
            // AVFoundation format / decoder errors.
            if err.domain == AVFoundationErrorDomain {
                let code = AVError.Code(rawValue: err.code)
                switch code {
                case .decodeFailed, .noCompatibleAlternatesForExternalDisplay:
                    return "decoder_error"
                case .fileFormatNotRecognized, .contentIsNotAuthorized:
                    return "parse_error"
                default:
                    break
                }
            }
            return "unknown"
        }
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

    /// Marks the controller as having produced its first renderable
    /// frame. Called by the platform view path when
    /// `AVPlayerLayer.isReadyForDisplay` flips to `true`, and by the
    /// texture path's `VideoTextureOutput.onFirstFrame` callback when
    /// a real `CVPixelBuffer` has actually been delivered to the
    /// Flutter texture (either via `tryPullFrameNow` from
    /// `safePreroll` for prefetched items, or via the
    /// `CADisplayLink` poll once playback begins). Flipping this flag
    /// hides the loader overlay in Flutter, so it must only happen
    /// after the texture has a buffer — otherwise the texture renders
    /// one frame of black before the next display-link tick.
    func setFirstFrameRendered() {
        guard !firstFrameRendered else { return }
        firstFrameRendered = true
        sendStateUpdate()
    }

    // MARK: - Video size

    private func updateVideoSize(from item: AVPlayerItem) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let size = item.presentationSize
            guard size.isPositive else { return }
            self.videoWidth = Int(abs(size.width))
            self.videoHeight = Int(abs(size.height))
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
        return Int(max(bufferedEnd, 0) * 1000)
    }

    // MARK: - App Lifecycle

    /// Whether the player was playing before the app went to background.
    private var wasPlayingBeforePause = false

    func onAppBackgrounded() {
        wasPlayingBeforePause = player?.rate ?? 0 > 0
        if wasPlayingBeforePause {
            player?.pause()
            audioOverlayManager.pauseAndDeactivateAll()
            sendStateUpdate()
        }
    }

    func onAppForegrounded() {
        if wasPlayingBeforePause {
            player?.play()
            player?.rate = Float(speed)
            audioOverlayManager.resumeActive(speed: speed)
            wasPlayingBeforePause = false
            sendStateUpdate()
        }
    }

    // MARK: - Dispose

    func dispose() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        pendingPrerollObservation?.invalidate()
        pendingPrerollObservation = nil
        NotificationCenter.default.removeObserver(self)
        textureOutput?.dispose()
        textureOutput = nil
        playerLooper = nil
        player?.pause()
        player?.removeAllItems()
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
    case noPlayableVideoTracks
    case invalidRenderSize

    var errorDescription: String? {
        switch self {
        case .cannotCreateTrack:
            return "Failed to create composition track."
        case .noPlayableVideoTracks:
            return "No playable video tracks found."
        case .invalidRenderSize:
            return "Video composition has an invalid render size."
        }
    }
}

private extension CGSize {
    var absoluteSize: CGSize {
        CGSize(width: abs(width), height: abs(height))
    }

    var isPositive: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0
    }
}

private extension CGAffineTransform {
    var isEffectivelyIdentity: Bool {
        abs(a - 1) < 0.001
            && abs(b) < 0.001
            && abs(c) < 0.001
            && abs(d - 1) < 0.001
            && abs(tx) < 0.001
            && abs(ty) < 0.001
    }

    func standardized(for size: CGSize) -> CGAffineTransform {
        var transform = self
        if close(a, 1) && close(b, 0) && close(c, 0) && close(d, 1) {
            transform.tx = 0
            transform.ty = 0
        } else if close(a, -1) && close(b, 0) && close(c, 0) && close(d, -1) {
            transform.tx = size.width
            transform.ty = size.height
        } else if close(a, 0) && close(b, -1) && close(c, 1) && close(d, 0) {
            transform.tx = 0
            transform.ty = size.width
        } else if close(a, 0) && close(b, 1) && close(c, -1) && close(d, 0) {
            transform.tx = size.height
            transform.ty = 0
        } else if close(a, -1) && close(b, 0) && close(c, 0) && close(d, 1) {
            transform.tx = size.width
            transform.ty = 0
        } else if close(a, 1) && close(b, 0) && close(c, 0) && close(d, -1) {
            transform.tx = 0
            transform.ty = size.height
        } else if close(a, 0) && close(b, -1) && close(c, -1) && close(d, 0) {
            transform.tx = size.height
            transform.ty = size.width
        } else if close(a, 0) && close(b, 1) && close(c, 1) && close(d, 0) {
            transform.tx = 0
            transform.ty = 0
        }
        return transform
    }

    private func close(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
