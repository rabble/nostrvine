# OpenVine Mobile Changelog

All notable changes to the OpenVine mobile application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-06-30

### Fixed
- **CRITICAL**: Resolved relay subscription limit (50 subscriptions) that was preventing video comments and interactions from loading on web platform
- Fixed video comment lazy loading to prevent subscription leaks when scrolling through feed
- Improved subscription management with proper cleanup when videos scroll out of view
- Enhanced error handling for comment count fetching with better timeout management

### Added  
- Implemented lazy comment loading in video feed items - comments only load when user taps comment button
- Added proper subscription management through SubscriptionManager for all comment-related operations
- Added `cancelCommentSubscriptions()` method in SocialService for cleaning up video-specific subscriptions
- Added subscription limits and priority handling to prevent relay overload
- Added enhanced error handling and logging for subscription management debugging

### Changed
- Modified `SocialService.fetchCommentsForEvent()` to use managed subscriptions instead of direct Nostr service calls
- Updated `getCommentCount()` to use SubscriptionManager with proper timeout and priority settings
- Increased SubscriptionManager concurrent subscription limit from 20 to 30 for better comment handling
- Enhanced video feed item UI to show lazy-loaded comment counts (shows "?" until loaded)
- Improved subscription cleanup patterns throughout social interaction services

### Technical Details
- Refactored comment subscription pattern from direct `_nostrService.subscribeToEvents()` to managed `_subscriptionManager.createSubscription()`
- Implemented StreamController pattern for proper event stream management in comment fetching
- Added subscription limits (50-100 events) to prevent excessive relay load
- Enhanced subscription timeout and priority management for different operation types
- Improved logging and debugging for subscription lifecycle management

### Web Platform
- Deployed subscription management fixes to resolve "Maximum number of subscriptions (50) reached" errors
- Fixed video interaction loading issues on web deployment
- Improved web performance through better subscription resource management