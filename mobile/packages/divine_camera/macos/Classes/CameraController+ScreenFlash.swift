// ABOUTME: Screen flash extension for CameraController
// ABOUTME: Implements warm-white overlay windows for face illumination on macOS

import AppKit
import AVFoundation

extension CameraController {

    /// Creates warm-white overlay windows on all screens to act as a fill light
    /// for the FaceTime camera. Each screen gets a borderless, topmost window
    /// with a rounded-rect ring at the edges (matching macOS rounded display
    /// corners) and a transparent centre so the camera preview stays visible.
    func enableScreenFlash() {
        guard screenFlashFeatureEnabled else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Already showing
            if !self.screenFlashWindows.isEmpty { return }

            for screen in NSScreen.screens {
                let window = NSWindow(
                    contentRect: screen.frame,
                    styleMask: .borderless,
                    backing: .buffered,
                    defer: false
                )
                window.level = .screenSaver
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.backgroundColor = .clear
                window.collectionBehavior = [
                    .canJoinAllSpaces,
                    .stationary,
                ]

                let flashView = ScreenFlashRingView(
                    frame: NSRect(
                        origin: .zero,
                        size: screen.frame.size
                    )
                )
                window.contentView = flashView

                window.orderFrontRegardless()
                self.screenFlashWindows.append(window)
            }

            print("DivineCamera macOS: Screen flash enabled")
        }
    }

    /// Removes all screen flash overlay windows.
    func disableScreenFlash() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let hadWindows = !self.screenFlashWindows.isEmpty
            for window in self.screenFlashWindows {
                window.orderOut(nil)
            }
            self.screenFlashWindows.removeAll()
            if hadWindows {
                print("DivineCamera macOS: Screen flash disabled")
            }
        }
    }

    /// Checks if the current environment is dark based on camera exposure.
    func isEnvironmentDark() -> Bool {
        // iso and exposureDuration are unavailable on macOS
        // Default to not-dark so screen flash is only triggered manually
        return false
    }

    /// Checks exposure values and enables auto-flash if needed.
    /// Called when recording starts.
    func checkAndEnableAutoFlash() {
        guard isAutoFlashMode else { return }

        if isEnvironmentDark() {
            print(
                "DivineCamera macOS: Auto flash: "
                    + "Dark environment detected - enabling screen flash"
            )
            autoFlashEnabled = true
            enableScreenFlash()
        } else {
            print(
                "DivineCamera macOS: Auto flash: "
                    + "Bright environment - flash not needed"
            )
        }
    }

    /// Disables auto-flash if it was enabled.
    func disableAutoFlash() {
        if autoFlashEnabled {
            disableScreenFlash()
            autoFlashEnabled = false
        }
    }

    /// Sets the flash mode.
    /// On macOS the only flash mechanism is the screen flash (warm overlay).
    func setFlashMode(mode: String) -> Bool {
        print("DivineCamera macOS: Setting flash mode: \(mode)")

        switch mode {
        case "off":
            disableScreenFlash()
            currentFlashMode = "off"
            isAutoFlashMode = false
            autoFlashEnabled = false

        case "auto":
            disableScreenFlash()
            currentFlashMode = "auto"
            isAutoFlashMode = true
            autoFlashEnabled = false

        case "torch":
            enableScreenFlash()
            currentFlashMode = "torch"
            isAutoFlashMode = false

        case "on":
            currentFlashMode = "on"
            isAutoFlashMode = false

        default:
            break
        }

        return true
    }
}

// MARK: - Screen Flash Ring View

/// Custom NSView that draws a warm-white rounded-rect ring matching
/// modern macOS display corners. The centre is transparent so the camera
/// preview remains visible while the border glows.
class ScreenFlashRingView: NSView {

    /// Corner radius matching modern MacBook / Studio Display bezels.
    private let displayCornerRadius: CGFloat = 30

    /// Width of the illuminated ring border.
    private let ringWidth: CGFloat = 80

    /// Warm-white colour (~5200 K) used for the flash ring.
    private let warmWhite = NSColor(
        calibratedRed: 1.0,
        green: 0.95,
        blue: 0.85,
        alpha: 1
    )

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        // Small inset so the ring doesn't sit flush against the screen edge
        let outerInset: CGFloat = 20
        let outerRect = bounds.insetBy(dx: outerInset, dy: outerInset)
        let outerPath = CGPath(
            roundedRect: outerRect,
            cornerWidth: displayCornerRadius,
            cornerHeight: displayCornerRadius,
            transform: nil
        )

        let innerRect = outerRect.insetBy(dx: ringWidth, dy: ringWidth)
        let innerCorner: CGFloat = 12
        let innerPath = CGPath(
            roundedRect: innerRect,
            cornerWidth: innerCorner,
            cornerHeight: innerCorner,
            transform: nil
        )

        // Build a ring: outer path with inner path cut out (even-odd fill)
        let ringPath = CGMutablePath()
        ringPath.addPath(outerPath)
        ringPath.addPath(innerPath)

        context.beginPath()
        context.addPath(ringPath)
        context.setFillColor(warmWhite.cgColor)
        context.fillPath(using: .evenOdd)
    }
}
