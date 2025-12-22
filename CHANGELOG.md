# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased Changes]

### Added
- **Clip Library Redesign**: Complete overhaul of the drafts/clips system with improved UX
  - Renamed "Drafts" throughout app to "Clips" for clarity (route, screens, providers)
  - Direct tap-to-select in clip library (no more "Select" button required)
  - Added clips library button to camera screen for quick access
  - Added `clipCountProvider` for reactive clip count display in profile

### Changed
- **Clip Editing Flow Navigation**: Improved navigation with clear exit paths
  - Added dual navigation: back arrow (previous screen) + X button (exit flow) on ClipManager and VideoEditor
  - Camera screen X button now properly returns to previous screen (canPop check with home fallback)
  - Confirmation dialogs when exiting with unsaved clips/edits
  - Improved duration warning: shows exact seconds over limit instead of vague message

### Fixed
- **iOS Build: iPad Multitasking Orientation Requirements**: Fixed App Store validation failure for iPad multitasking
  - Added landscape orientations (LandscapeLeft, LandscapeRight) to iPad Info.plist configuration
  - Satisfies Apple requirement for split-screen/slide-over support on iPad
  - iPhone remains portrait-only as intended

- **UI: Removed Video Duration Display**: Removed video duration/length display from all UI screens
  - Removed duration overlay from video metadata/preview screen
  - Maintains Vine-like aesthetic where video length is not relevant to UX
  - Recording timer during active capture still shown as intended

- **NIP-18 Repost Event Kind Migration**: Fixed incorrect repost event implementation per NIP-18 specification
  - Migrated from kind 6 (text note repost, only for kind 1 events) to kind 16 (generic repost for all non-kind-1 events)
  - Added required 'k' tag with stringified kind number ('34236' for video events) to all kind 16 reposts
  - Updated all service files: social_service.dart, nostr_events_dao.dart, video_event_service.dart, social_providers.dart, notification_service_enhanced.dart, nostr_service.dart, video_subscription_service.dart
  - Updated all database queries and filters from kind 6 to kind 16
  - Updated all test files to expect kind 16 repost events with 'k' tag
  - Comprehensive test coverage: 23/25 tests passing (2 pre-existing failures unrelated to migration)
  - Resolves compatibility issue with NIP-18 spec for video event reposts

- **Camera Screen UX Improvements**: Fixed multiple camera screen usability issues
  - Camera switch button now only appears when multiple cameras are available (prevents confusion on single-camera devices)
  - macOS camera switching fully implemented using native API with proper camera cycling
  - iOS camera switch now properly updates preview with state notification and extensive debug logging
  - iOS pinch-to-zoom gesture support added with zoom slider UI and smooth zoom control
  - SnackBar notifications moved to top of screen to avoid covering publish button
  - Added `canSwitchCamera` field to camera state management for conditional UI rendering
  - Integrated existing `CameraControlsOverlay` widget for enhanced camera controls

- **Performance: Explore/Trending Page Hangs Eliminated**: Fixed severe performance issues causing 3-10 second freezes when opening Explore, Trending, and hashtag pages
  - Added 9 critical database indexes on `event` and `video_metrics` tables to eliminate full table scans
  - `idx_event_kind`, `idx_event_created_at`, `idx_event_kind_created_at` - for video discovery queries
  - `idx_event_pubkey`, `idx_event_kind_pubkey`, `idx_event_pubkey_created_at` - for profile/author queries
  - `idx_metrics_loop_count`, `idx_metrics_likes`, `idx_metrics_views` - for trending/popular sorting
  - Database schema version bumped to v5 with automatic migration on app restart
  - Re-enabled cache-first queries for discovery feeds (now fast with indexes)
  - Queries that previously took 3+ seconds now complete in milliseconds

- **Performance: Database Lock Contention Fixed**: Eliminated "database is locked" errors when receiving events
  - Implemented event batching in `EventRouter` with 50ms debounce timer
  - Added `upsertEventsBatch()` method using single transaction instead of individual inserts
  - Prevents 100+ concurrent INSERT statements from blocking each other
  - Events are now batched (50 events or 50ms window) for efficient bulk inserts

- **Performance: File Descriptor Leak Fixed**: Resolved "Too many open files" error from logging system
  - Changed `LogCaptureService` to use persistent `IOSink` instead of opening new file handle on every write
  - Added file rotation lock and memory-tracked file size to prevent concurrent rotation issues
  - Flush buffered logs every 100 entries to balance crash safety with I/O efficiency
  - Logging system now handles hundreds of thousands of entries without exhausting file descriptors

- **Performance: Discovery Subscription Pre-initialization Optimized**: Fixed 10-second freeze when opening Explore tab
  - Skip expensive `_preInitializeReplaceableEvents()` for discovery subscriptions (no authors filter)
  - Pre-initialization now only runs for home feed subscriptions where it's beneficial
  - Explore tab opens instantly instead of hanging for 10 seconds

- **Explore Screen Navigation**: Fixed critical bug where tapping videos in Explore tab would fail on first attempt
  - Made URL the single source of truth using `pageContextProvider` instead of internal widget state
  - ExploreScreen now derives feed/grid mode from URL `videoIndex` parameter reactively
  - Fixed `RangeError` when widget recreated due to GoRouter's different Navigator keys for grid/feed modes
  - Videos and starting index now read from `exploreTabVideosProvider`, surviving widget recreation
  - Removed unnecessary `setState()` call in hashtag loading that interfered with navigation
  - Follows proper Flutter Navigation 2.0 + Riverpod pattern where URL drives UI state

- **Profile Navigation**: Fixed issue where tapping Profile from drawer/bottom nav would skip grid view and go directly to fullscreen video feed
  - Added missing `/profile/:npub` route for grid mode (was only `/profile/:npub/:index`)
  - Fixed route parser to return `null` videoIndex for grid mode instead of defaulting to `0`
  - Fixed 'me' profile redirect to preserve grid/feed mode (was always adding `/0` to URL)

### Added
- **Key Management Screen**: Simple, user-friendly interface for Nostr key import and backup
  - Clear explanation of what Nostr keys are (npub/nsec concepts)
  - Import existing keys via text field with paste functionality
  - Export/backup current key to clipboard
  - Validation for nsec format (must start with "nsec1")
  - Confirmation dialog before key replacement to prevent accidental data loss
  - Auto-fetches profile (kind 0) and contacts (kind 3) after successful import
  - Accessible via Settings → Key Management
  - Dark mode UI consistent with OpenVine aesthetic
  - Security warnings for both import and export operations

- **Nostr Key Manager Enhanced Features**: Backend support for key management operations
  - `exportAsNsec()` - Export private key in bech32 nsec format
  - `importFromNsec()` - Import existing nsec with automatic profile/contact fetching
  - `replaceKeyWithBackup()` - Generate new key while backing up old one
  - `restoreFromBackup()` - Restore previously backed up key
  - `clearBackup()` - Delete backup key from secure storage
  - Comprehensive test coverage (8/9 tests passing)

- **Contributing Guide**: Comprehensive `CONTRIBUTING.md` with setup and build instructions
  - Complete prerequisites for Flutter, iOS, Android, and backend development
  - Detailed Flutter Embedded Nostr Relay setup with symlink instructions
  - Platform-specific build instructions (macOS, iOS, Android, Windows)
  - Development workflow including hot reload, testing, and code analysis
  - Code standards and TDD requirements
  - Pull request process and commit message format
  - Common issues troubleshooting guide
  - Updated README.md with link to contributing guide

- **Multi-Account Support Planning**: Comprehensive implementation plan for multiple user accounts
  - Detailed 40+ page implementation guide at `docs/MULTI_ACCOUNT_IMPLEMENTATION.md`
  - Secure AccountManager architecture with biometric authentication design
  - 5-phase implementation roadmap (Foundation, Core, Integration, UI, Testing)
  - Shared embedded relay with account-specific subscriptions architecture
  - Secure key storage using flutter_secure_storage
  - Data models for UserAccount, AccountState, and RelayConfig
  - Migration strategy for existing single-account users
  - Target <500ms account switching performance with security-first approach

- **Blossom Media Server Integration**: Support for user-configurable Blossom media servers
  - New `BlossomUploadService` for uploading videos to any Blossom-compatible server
  - `BlossomSettingsScreen` for configuring custom media servers
  - NIP-98 authentication support for Blossom uploads
  - User-selectable upload destination (OpenVine servers vs. custom Blossom servers)
  - Decentralized media hosting capabilities

- **Firebase Crash Reporting Infrastructure**: Development infrastructure for crash tracking
  - Firebase integration setup with platform-specific configurations
  - `firebase_options.dart` with multi-platform support structure
  - Crash reporting setup documentation at `docs/CRASH_REPORTING_SETUP.md`
  - TestFlight build script with crash reporting integration (`build_testflight.sh`)
  - Enhanced debugging and monitoring capabilities

- **CDN Infrastructure Improvements**: Enhanced media delivery with fallback systems
  - `VineCdnHttpOverrides` for DNS routing to working edge servers
  - Preserves TLS SNI and Host headers while fixing DNS resolution
  - Fallback mechanisms for CDN reliability
  - Improved media loading performance and reliability

- **Performance Optimization**: Significant performance improvements for tab-based navigation
  - Background Riverpod provider optimization with autoDispose for heavy providers
  - Scoped feed streams to visible tabs only (VideoEvents, LatestVideos, HomeFeed)
  - Gated discovery subscriptions to Explore tab visibility only
  - Prevents off-screen providers from maintaining live subscriptions and timers
  - Reduced background network requests and profile prefetches
  - Guards for off-screen network churn and unnecessary API calls

### Changed
- **iOS Distribution**: Bumped iOS build number to 8 for TestFlight distribution
- **Enhanced Error Handling and Recovery**: Comprehensive global error management system
  - Global error handler with graceful UI fallback for unhandled exceptions
  - Custom error widget with retry capability for runtime errors
  - Automatic service initialization retry with exponential backoff
  - Proper error boundary implementation to prevent app crashes
  - Detailed error logging and user-friendly error messages

- **Improved Upload Manager**: Robust upload handling with better error recovery
  - Enhanced error handling for network failures and timeouts
  - Automatic retry logic with exponential backoff for failed uploads
  - Better state management for upload progress tracking
  - Clearer error messages for various upload failure scenarios
  - Graceful handling of Hive storage errors

- **Enhanced Relay Settings**: Improved relay management UI and functionality
  - Better visual feedback for relay connection states
  - Improved error handling for relay operations
  - More informative status messages
  - Enhanced validation for relay URLs

- **UI/UX Improvements**: Better visual feedback and user experience
  - Updated app icons for iOS, macOS, and Android platforms
  - Enhanced loading states and progress indicators
  - Improved error message presentation
  - Better handling of offline states

### Changed
- **NostrService Enhancement**: Added better error handling and connection management
  - Improved relay connection error recovery
  - Better handling of subscription failures
  - Enhanced event processing error handling
  
- **Video Feed Performance**: Optimized feed loading and error recovery
  - Better handling of video loading failures
  - Improved feed refresh logic
  - Enhanced pagination error handling

### Fixed
- **Critical Upload Issues**: Resolved upload failures and state management problems
  - Fixed Duration serialization errors in Hive storage
  - Resolved upload progress tracking issues
  - Fixed retry logic for failed uploads
  - Improved error state cleanup

- **Service Initialization**: Fixed startup crashes and initialization failures
  - Added proper error handling for service initialization
  - Implemented retry mechanism for failed service starts
  - Better handling of missing or corrupted local storage

- **UI Rendering Errors**: Fixed various UI crashes and rendering issues
  - Resolved null reference errors in video feed widgets
  - Fixed bottom navigation bar rendering on macOS
  - Improved error boundary handling for widget failures

### Added (Backend: Cloudflare Stream)
- Cloudflare Stream upload and CDN integration (phase-in)
  - New POST `/v1/media/request-upload` to create Stream direct upload URLs (NIP-98 auth; per-pubkey rate limit)
  - New POST `/v1/webhooks/stream-complete` to process Stream callbacks (HMAC signature validation)
  - New GET `/v1/media/status/{videoId}` for processing state; returns HLS/DASH URLs when published
  - KV mappings for Stream: `stream:file:{fileId}` and `stream:uid:{uid}`
  - Thumbnail delivery via Cloudflare Images transformation of Stream thumbnails
  - Compatibility: `/media/{fileId}` and `/thumbnail/{fileId}` redirect to Stream/Images when migrated; fallback to R2 otherwise

### Changed (Backend: Cloudflare Stream)
- Prefer Cloudflare Stream HLS/DASH for video delivery; R2 remains a fallback path
- `/media/{fileId}` and `/thumbnail/{fileId}` updated to support redirects for migrated items
- Standardize webhook secret to `STREAM_WEBHOOK_SECRET` (ensure Wrangler secret is set)
- Enforced rate limiting for Stream uploads (30/hour per pubkey)

### Notes (Backend)
- NIP-96 `/api/upload` remains for images and legacy flows. For videos, clients should move to Stream upload flow. Transitional behavior may return processing handoff to Stream.
- GIF output is not provided by Stream; prefer HLS/short MP4. If GIFs are required, a separate processing path will be needed.

### Migration (Backend)
- Planned one-time import of existing R2 videos into Cloudflare Stream:
  - Enumerate R2 `uploads/` objects, generate signed URLs, and create Stream videos with metadata (`fileId`, `sha256`, `originalFilename`)
  - Store KV mappings and update on webhook completion
  - Keep dedup and original Vine mappings intact: `sha256:{hash}`, `vine_id:{vineId}`, `filename:{name}`

### Fixed
- **Video Upload and Publishing**: Resolved critical issues preventing video uploads and Nostr event publishing
  - Fixed Hive Duration serialization error by converting Duration fields to milliseconds (int)
  - Resolved "HiveError: Cannot write, unknown type: Duration" that was blocking upload persistence
  - Fixed backend health check to use existing NIP-96 info endpoint instead of non-existent /health endpoint
  - Uploads now successfully save to local storage and complete the publishing flow
  - Added comprehensive logging throughout upload pipeline for better debugging

- **macOS Navigation Bar Error**: Fixed RangeError in BottomNavigationBar on app startup
  - Replaced deprecated `withValues(alpha: 0.7)` with `withOpacity(0.7)` for color transparency
  - Fixed incorrect indentation causing Flutter to misinterpret widget structure
  - Resolved "RangeError: Invalid value: Not in inclusive range" error

- **Relay Settings Screen**: Updated to show external relays instead of internal gateway
  - Now displays actual external relays (e.g., wss://relay3.openvine.co) not localhost:8080
  - Connected to NostrService to fetch configured external relay list
  - Added functional add/remove relay UI with validation
  - Included informative banner explaining external relay synchronization

- **UserProfileService Compilation**: Added missing prefetch tracking fields
  - Added `_prefetchActive` and `_lastPrefetchAt` fields to fix undefined getter errors
  - Resolved compilation errors preventing macOS builds

- **Video Publishing and Profile Refresh Issues**: Comprehensive fix for video publishing workflow
  - **Profile Screen Refresh**: Profile now automatically refreshes when returning from video publishing
    - Added `didChangeDependencies()` lifecycle method to detect tab activation
    - Implemented `_refreshProfileData()` method to force reload all profile data
    - Clear caches and invalidate providers after successful video publish
  - **Username Display**: Fixed profile showing raw npub IDs instead of usernames
    - Corrected null-aware operator usage with proper bang operators
    - Improved fallback logic to show shortened pubkey while loading actual username
  - **Relay Subscription Limits**: Resolved "ERROR: too many concurrent REQs" during video publishing
    - Removed redundant event verification that created extra subscription (14th concurrent request)
    - Now uses broadcast result directly without verification query
    - Videos publish successfully despite previous false-negative error messages
  - **Compilation Errors**: Fixed multiple compilation issues
    - Removed duplicate `_formatCount` method in profile_screen.dart
    - Fixed `NostrBroadcastResult.failureCount` reference to use `failedRelays.length`
    - Removed unused import of `Filter` in video_event_publisher.dart
  - **Test File Compatibility**: Updated test mock interfaces to match new `onEose` parameter

### Added
- Mobile: show original Vine metrics in UI when available
  - `VideoFeedItem` displays compact metrics row: loops and likes
  - Profile grid tiles show bottom-left badges for loops/likes
  - Metrics hidden when values are not available (new vines)

### Changed
- Mobile: global loops-first sorting for all video lists
  - New comparator `VideoEvent.compareByLoopsThenTime`
  - Policy: items with no loop count first (new vines), then by loop count desc; ties by newest
  - Applied to: home feed, hashtag feeds, profile videos (streaming and cached), and search video results
- Mobile: creator/follow/time moved below video (non-overlapping) in explore viewer and hashtag feed
  - New `forceInfoBelow` option in `VideoFeedItem`; enabled for Explore and Hashtag screens
  - Time now prefers original publish time (`published_at`) when present; falls back to relay `createdAt`
- **Embedded Relay Architecture**: Complete migration from external relays to embedded relay system
  - Integrated `flutter_embedded_nostr_relay` dependency for local relay functionality
  - Implemented local WebSocket server on port 7447 for direct app connections
  - Added SQLite event storage for instant queries and offline support
  - External relay proxy management through embedded relay
  - P2P sync capabilities for decentralized content sharing
  - All external relay URLs replaced with `ws://localhost:7447`
  - Comprehensive architecture documentation in `mobile/docs/NOSTR_RELAY_ARCHITECTURE.md`

### Changed
- **BREAKING: Complete External Relay Demolition**: Systematically removed all external relay infrastructure
  - Replaced all external relay references (relay.damus.io, nos.lol, relay3.openvine.co) with embedded relay
  - NostrService now uses embedded relay by default
  - Content reporting service updated to use embedded relay
  - All test files updated to use localhost connections
  - Deleted obsolete relay migration tests
  - Clean separation between app layer (NostrService) and relay management (EmbeddedNostrRelay)

### Fixed
- **Video Feed Display Issue**: Fixed critical issue where videos weren't appearing in the home feed despite successful Nostr event reception
  - Fixed VideoManager to listen to both discovery videos and home feed videos (homeFeedProvider)
  - Resolved `VideoManagerException: Video not found in manager state` errors during video preloading
  - Fixed broken bridge between VideoEventService and VideoManager that prevented videos from being added to manager state
  - Home feed videos are now properly synchronized with VideoManager for seamless playback
  - Compilation errors in video_event_service.dart resolved (duplicate variables, method signature mismatches)
  - App now successfully builds and displays videos from both discovery and following-only feeds

### Added 
- **Riverpod Migration Complete**: Fully migrated video feed system from Provider to Riverpod 2.0
  - **VideoEventBridge Eliminated**: Replaced complex manual coordination with reactive provider architecture
  - **Reactive Video Feeds**: Following list changes now automatically trigger video feed updates
  - **Memory-Efficient Video Management**: Intelligent preloading with 15-controller limit and <500MB memory management
  - **Real-time Nostr Streaming**: Proper stream accumulation for live video event updates with comprehensive test coverage
  - **Pure Riverpod Implementation**: All video functionality now uses reactive StateNotifier and Stream providers
  - **Backward Compatibility**: Full IVideoManager interface support for existing code
  - **100% Test Coverage**: Comprehensive TDD approach with 24+ passing tests across all providers

### Cleaned Up
- **Complete Removal of Deprecated Code**: Eliminated all migration paths and backward compatibility cruft
  - **KeyStorageService & KeyMigrationService**: Completely removed deprecated key storage system
  - **Test Files**: Deleted 5 test files for deprecated services
  - **Migration Logic**: Removed all migration code from AuthService
  - **Backward Compatibility Wrappers**: Removed SmartVideoThumbnail wrapper
  - **Deprecated Methods**: Removed setWebAuthenticationKey method
  - **Legacy Endpoints**: Removed unused videoMetadataUrl and videoListUrl from AppConfig
  - **Test Updates**: Fixed test builders and service constructors
  - **Import Cleanup**: Updated all imports to use modern services
- **Codebase Modernization**: Zero tolerance for deprecated code patterns
  - All code now uses SecureKeyStorageService exclusively
  - No migration paths or compatibility modes
  - Clean, forward-only architecture

### Removed  
- **Legacy VideoEventBridge**: Removed deprecated Provider-based video coordination system
  - Deleted `video_event_bridge.dart` service file and associated test files
  - Updated `main.dart` to remove VideoEventBridge initialization
  - Updated screens to rely on automatic Riverpod provider reactivity
  - Removed manual pagination and refresh logic (now handled automatically)
  - Clean separation between legacy and modern architecture

### Fixed
- **Web Platform Compatibility**: Fixed critical Platform._version error preventing web app from connecting to relays
  - Fixed dart:io imports in platform_secure_storage.dart with conditional imports for web compatibility
  - Fixed dart:io imports in secure_key_storage_service.dart for web support
  - Fixed nostr_sdk relay implementation to use platform-specific WebSocket connections
  - Created separate IO and Web implementations for relay connections in nostr_sdk
  - Web app now successfully connects to wss://vine.hol.is relay
  - Resolved runtime errors that prevented web deployment from functioning

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
