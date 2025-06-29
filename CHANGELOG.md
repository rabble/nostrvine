# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Reduced Logging Verbosity**: Significantly reduced excessive console logging
  - Removed verbose curation service logging that spammed console on every video event
  - Converted excessive `Log.info` statements to `Log.debug` or removed entirely
  - Eliminated redundant websocket message logging (`DEBUG: Received message from wss://vine.hol.is: EVENT`)
  - Cleaned up repetitive "Editor's Picks selection" and "Populating curation sets" log spam
  - Improved development experience with cleaner, more focused console output

### Added
- **NIP-05 Username Registration**: Complete NIP-05 verification system with username availability checking
  - Username registration service with backend integration
  - Real-time availability checking and validation
  - Profile setup screen integration with username selection
  - Reserved username protection and error handling
- **Analytics Service**: Comprehensive analytics tracking for user interactions and video engagement
  - Video view tracking with unique session management
  - User interaction analytics (likes, follows, shares)
  - Analytics service with privacy-focused data collection
  - Performance metrics and user engagement tracking
- **Identity Management**: Advanced identity switching and management capabilities
  - Multiple identity storage and switching functionality
  - Identity manager service for seamless account transitions
  - Secure identity persistence and recovery
  - Enhanced authentication flows with identity validation
- **Age Verification System**: COPPA-compliant age verification for user onboarding
  - Age verification dialog with proper validation
  - Compliance with child protection regulations
  - User-friendly age verification flow
  - Privacy-focused age checking without data retention
- **Subscription Management**: Centralized subscription management for Nostr connections
  - Unified subscription manager for efficient relay management
  - Connection pooling and optimization
  - Automatic retry and failover mechanisms
  - Enhanced connection stability and performance
- **Profile Cache Service**: Advanced caching system for user profiles and metadata
  - Intelligent profile caching with TTL management
  - Background profile updates and synchronization
  - Memory-efficient cache implementation
  - Improved profile loading performance
- **Logging Configuration**: Centralized logging system with configurable levels
  - Structured logging with multiple output formats
  - Configurable log levels for different environments
  - Performance-optimized logging for production use
  - Debug and development logging capabilities
- **Video Playback Controller**: Enhanced video playback with advanced controls
  - Video playback widget with gesture controls
  - Playback state management and synchronization
  - Performance-optimized video rendering
  - Cross-platform video playback consistency
- **Relay Settings Screen**: User interface for managing Nostr relay connections
  - Visual relay management with connection status
  - Add/remove relay functionality
  - Connection health monitoring and diagnostics
  - User-friendly relay configuration

### Changed
- **BREAKING**: Complete rebrand from NostrVine to OpenVine
  - Updated all package imports from `nostrvine_app` to `openvine` (76+ files)
  - Changed app title and branding throughout the application
  - Updated all documentation files to reflect new branding
  - Modified test files and deployment scripts
  - Updated platform-specific configuration (iOS/Android/macOS)
  - Changed all code comments and internal documentation
  - Updated deployment and build scripts
  - Changed macOS camera permission text
  - Maintained Cloudflare infrastructure compatibility (no backend changes)

### Added  
- **Flutter Web Performance Optimization**: Comprehensive performance improvements for web platform
  - Service worker with aggressive caching (cache-first for static assets, network-first for APIs)
  - Tree-shaking optimization (99.1% reduction in Material Icons from 1.6MB to 14KB)
  - Lazy loading for non-critical services (3-second delay on web)
  - Resource hints (DNS prefetch, preconnect) for faster initial loads
  - Maximum build optimization with obfuscation and compression
- **Activity Screen Video Playback**: Activity screen notifications now have clickable video thumbnails that open videos in the full player
- **Comprehensive Video Sharing Menu**: Added full share menu with content reporting, list management, and social sharing features
- **URL Domain Correction**: Automatic fixing of incorrect `apt.openvine.co` URLs to `api.openvine.co` for legacy Nostr events
- **Enhanced Error Handling**: Added proper validation and user feedback for invalid video URLs
- **Debug Logging**: Comprehensive logging system for tracking video URL parsing and corrections

### Fixed
- **Video Loading Issues**: Fixed videos getting stuck on "Loading..." when opened from Activity screen
- **Domain Configuration**: Corrected domain mismatches that caused video loading failures
- **Activity Screen Navigation**: Fixed navigation flow from activity notifications to video player
- **URL Validation**: Added proper URL validation with user-friendly error messages
- **Share Menu Functionality**: Restored missing share menu methods and improved user experience

### Changed
- **Web Performance**: Expected 60% faster first contentful paint (8-12s → 3-5s) and 75% faster repeat visits
- **Bundle Size**: 64% reduction in web bundle size (10MB → 3.6MB) through aggressive optimization
- **Improved Activity Screen UX**: Activity items now provide better visual feedback and clickable interactions
- **Enhanced Video Event Parsing**: More robust parsing of Nostr video events with automatic URL correction
- **Better Error Recovery**: Videos with malformed URLs now show helpful error messages instead of infinite loading

### Technical Improvements
- **Web Optimization**: Service worker implementation with multiple cache strategies for optimal performance
- **Build Pipeline**: Optimized Flutter web build with tree-shaking, obfuscation, and compression
- **Code Quality**: Fixed compilation errors and improved code organization
- **Performance**: Optimized video loading and error handling
- **Logging**: Added comprehensive debug logging for troubleshooting video issues
- **Architecture**: Improved separation of concerns between UI and business logic
- **iOS Keychain Access**: Fixed iOS keychain access errors by implementing direct flutter_secure_storage integration
  - Resolved MissingPluginException for custom MethodChannel 'openvine.secure_storage'
  - Fixed NIP-42 authentication failures that prevented video event reception
  - Eliminated -34018 keychain access errors through proper iOS platform integration
  - Improved app stability and authentication reliability on iOS devices

---

## Previous Releases

### [1.0.0] - Initial Release
- Core Vine-style video recording and playback
- Nostr protocol integration
- Flutter mobile app with camera functionality
- Cloudflare Workers backend
- Basic social features (follow, like, comment)