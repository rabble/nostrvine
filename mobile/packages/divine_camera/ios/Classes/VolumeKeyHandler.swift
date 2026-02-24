// ABOUTME: Handles volume button and media button events for remote recording (iOS)
// ABOUTME: Supports Bluetooth accessories via MPRemoteCommandCenter and volume buttons

import AVFoundation
import MediaPlayer
import UIKit

/// Handles volume button presses and Bluetooth media button events
/// for remote recording control on iOS.
class VolumeKeyHandler: NSObject {
    private var isEnabled = false
    private var volumeKeysEnabled = true  // Can be toggled independently
    private var onTrigger: ((String) -> Void)?
    
    // Volume button detection
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var lastVolume: Float = 0.5
    private var isObservingVolume = false
    
    // Track volume changes to detect button presses
    private var volumeChangeTimer: Timer?
    private var isInternalVolumeChange = false
    
    // Cooldown after activation to ignore spurious Bluetooth events.
    // Must be long enough to cover delayed events from AirPods/Apple Watch
    // that arrive after audio route changes during camera initialization.
    private var enabledTimestamp: TimeInterval = 0
    private let activationCooldownSeconds: TimeInterval = 3.0
    
    // Debounce between Bluetooth triggers to prevent rapid-fire events
    private var lastBluetoothTriggerTimestamp: TimeInterval = 0
    private let bluetoothDebounceSeconds: TimeInterval = 1.0
    
    // Temporary suppression during camera switch / audio route changes
    private var isSuppressed = false
    
    init(onTrigger: @escaping (String) -> Void) {
        self.onTrigger = onTrigger
        super.init()
    }
    
    /// Enables volume button listening.
    /// Sets up MPRemoteCommandCenter for Bluetooth remotes and volume observation.
    /// Returns true if successfully enabled.
    func enable() -> Bool {
        if isEnabled {
            return true
        }
        
        // NOTE: We intentionally do NOT configure the audio session here.
        // The camera already configures its own audio session for video recording.
        // Setting .playAndRecord with Bluetooth options causes iOS to trigger
        // "call start/end" sounds on Bluetooth headsets, which is undesirable.
        // MPRemoteCommandCenter and volume KVO work without specific audio session setup.
        
        setupRemoteCommandCenter()
        setupVolumeObserver()
        
        isEnabled = true
        volumeKeysEnabled = true
        enabledTimestamp = ProcessInfo.processInfo.systemUptime
        
        // Suppress triggers initially to absorb any spurious Bluetooth events
        // that fire when MPRemoteCommandCenter handlers are first registered.
        // Connected AirPods/Apple Watch may send play/pause events when they
        // detect a new "now playing" app.
        isSuppressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + activationCooldownSeconds) { [weak self] in
            self?.isSuppressed = false
            NSLog("DivineCameraVolumeKeyHandler: Initial suppression ended")
        }
        NSLog("DivineCameraVolumeKeyHandler: Enabled (suppressed for \(activationCooldownSeconds)s)")
        return true
    }
    
    /// Disables volume button listening.
    func disable() {
        if !isEnabled {
            return
        }
        
        teardownRemoteCommandCenter()
        teardownVolumeObserver()
        
        isEnabled = false
        volumeKeysEnabled = true
        NSLog("DivineCameraVolumeKeyHandler: Disabled")
    }
    
    /// Enable or disable volume key interception.
    /// When disabled, volume buttons will change system volume instead of triggering recording.
    /// Bluetooth media buttons are NOT affected by this setting.
    func setVolumeKeysEnabled(_ enabled: Bool) {
        volumeKeysEnabled = enabled
        NSLog("DivineCameraVolumeKeyHandler: Volume keys \(enabled ? "enabled" : "disabled")")
    }
    
    /// Whether volume key handling is currently enabled.
    func isHandlerEnabled() -> Bool {
        return isEnabled
    }
    
    /// Temporarily suppress all triggers for the given duration.
    ///
    /// Used during camera switch and other operations that cause
    /// iOS audio route changes, which can trigger spurious Bluetooth
    /// play/pause events from connected devices (e.g. Apple Watch).
    func suppressTemporarily(forSeconds duration: TimeInterval = 1.0) {
        isSuppressed = true
        NSLog("DivineCameraVolumeKeyHandler: Suppressed for \(duration)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isSuppressed = false
            NSLog("DivineCameraVolumeKeyHandler: Suppression ended")
        }
    }
    
    /// Cleanup resources.
    func release() {
        disable()
        onTrigger = nil
    }
    
    // MARK: - Remote Command Center (Bluetooth remotes/earbuds)
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play/Pause toggle (most common on Bluetooth headphones)
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth toggle play/pause")
            self?.handleBluetoothTrigger()
            return .success
        }
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth play")
            self?.handleBluetoothTrigger()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth pause")
            self?.handleBluetoothTrigger()
            return .success
        }
        
        // Enable the commands
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        
        // Set up now playing info to make remote commands work
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Recording"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        NSLog("DivineCameraVolumeKeyHandler: Remote command center configured")
    }
    
    private func teardownRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Bluetooth Trigger Handling
    
    /// Handles a Bluetooth remote trigger with cooldown and debounce protection.
    ///
    /// Filters out:
    /// - Events during activation cooldown (spurious events when enabling)
    /// - Events during temporary suppression (camera switch / route changes)
    /// - Rapid-fire duplicate events (debounce)
    private func handleBluetoothTrigger() {
        let now = ProcessInfo.processInfo.systemUptime
        
        // Check suppression (camera switch in progress)
        if isSuppressed {
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth trigger ignored - suppressed")
            return
        }
        
        // Check activation cooldown
        let timeSinceEnabled = now - enabledTimestamp
        if timeSinceEnabled < activationCooldownSeconds {
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth trigger ignored - within \(String(format: "%.0f", activationCooldownSeconds * 1000))ms activation cooldown (\(String(format: "%.0f", timeSinceEnabled * 1000))ms since enabled)")
            return
        }
        
        // Check debounce between triggers
        let timeSinceLastTrigger = now - lastBluetoothTriggerTimestamp
        if timeSinceLastTrigger < bluetoothDebounceSeconds {
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth trigger ignored - debounce (\(String(format: "%.0f", timeSinceLastTrigger * 1000))ms since last)")
            return
        }
        
        lastBluetoothTriggerTimestamp = now
        NSLog("DivineCameraVolumeKeyHandler: Bluetooth trigger accepted")
        
        // Refresh now playing info so iOS keeps routing remote events to us.
        // Without this, audio session changes during recording start/stop can
        // cause iOS to disassociate our app from MPNowPlayingInfoCenter,
        // making AirPods stop sending events to our command handlers.
        refreshNowPlayingInfo()
        
        onTrigger?("bluetooth")
    }
    
    /// Refreshes MPNowPlayingInfoCenter to keep our app as the active
    /// "now playing" app. Without this, iOS may stop routing AirPods/Apple
    /// Watch button presses to our MPRemoteCommandCenter handlers after
    /// audio session changes (e.g. recording start/stop).
    private func refreshNowPlayingInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Recording"
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Volume Button Detection
    
    private func setupVolumeObserver() {
        // Get current volume
        lastVolume = AVAudioSession.sharedInstance().outputVolume
        
        // Create a hidden MPVolumeView to prevent the system volume HUD from appearing
        let volumeView = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        volumeView.showsRouteButton = false
        volumeView.showsVolumeSlider = true
        
        // Find the volume slider within the view
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                self.volumeSlider = slider
                break
            }
        }
        
        // Add to window to receive events
        if let window = UIApplication.shared.windows.first {
            window.addSubview(volumeView)
            self.volumeView = volumeView
        }
        
        // Observe volume changes via KVO
        AVAudioSession.sharedInstance().addObserver(
            self,
            forKeyPath: "outputVolume",
            options: [.new, .old],
            context: nil
        )
        isObservingVolume = true
        
        NSLog("DivineCameraVolumeKeyHandler: Volume observer configured")
    }
    
    private func teardownVolumeObserver() {
        if isObservingVolume {
            AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
            isObservingVolume = false
        }
        
        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "outputVolume",
              let newValue = change?[.newKey] as? Float,
              let oldValue = change?[.oldKey] as? Float else {
            return
        }
        
        // Only trigger if volume keys are enabled and this is an external change
        if !isInternalVolumeChange && isEnabled && volumeKeysEnabled {
            if newValue > oldValue {
                NSLog("DivineCameraVolumeKeyHandler: Volume up button pressed")
                onTrigger?("volumeUp")
                
                // Restore volume to prevent actual volume change
                restoreVolume(to: oldValue)
            } else if newValue < oldValue {
                NSLog("DivineCameraVolumeKeyHandler: Volume down button pressed")
                onTrigger?("volumeDown")
                
                // Restore volume to prevent actual volume change
                restoreVolume(to: oldValue)
            }
        }
        // If volume keys are disabled, let the volume change through (don't restore)
    }
    
    /// Restores the volume to the previous level to prevent actual volume changes
    private func restoreVolume(to level: Float) {
        isInternalVolumeChange = true
        
        // Use the hidden slider to set volume without showing the HUD
        DispatchQueue.main.async { [weak self] in
            self?.volumeSlider?.setValue(level, animated: false)
            
            // Reset the flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.isInternalVolumeChange = false
            }
        }
    }
}
