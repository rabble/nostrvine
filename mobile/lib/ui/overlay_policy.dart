// ABOUTME: Injectable policy for controlling video overlay visibility in tests
// ABOUTME: Allows tests to force overlays on/off while preserving production auto behavior

export 'package:openvine/providers/overlay_policy_provider.dart'
    show overlayPolicyProvider;

enum OverlayPolicy { auto, alwaysOn, alwaysOff }
