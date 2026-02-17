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
        NSLog("DivineCameraVolumeKeyHandler: Enabled")
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
            self?.onTrigger?("bluetooth")
            return .success
        }
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth play")
            self?.onTrigger?("bluetooth")
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            NSLog("DivineCameraVolumeKeyHandler: Bluetooth pause")
            self?.onTrigger?("bluetooth")
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
