// ABOUTME: Build configuration service providing compile-time feature flag defaults
// ABOUTME: Maps environment variables to feature flag defaults for build-time configuration

import 'package:openvine/features/feature_flags/models/feature_flag.dart';

class BuildConfiguration {
  const BuildConfiguration();

  /// Get the default value for a feature flag from environment variables
  bool getDefault(FeatureFlag flag) {
    switch (flag) {
      case FeatureFlag.enhancedAnalytics:
        return const bool.fromEnvironment('FF_ENHANCED_ANALYTICS');
      case FeatureFlag.debugTools:
        return const bool.fromEnvironment('FF_DEBUG_TOOLS', defaultValue: true);
      case FeatureFlag.curatedLists:
        return const bool.fromEnvironment(
          'FF_CURATED_LISTS',
          defaultValue: true,
        );
      case FeatureFlag.blueskyPublishing:
        return const bool.fromEnvironment('FF_BLUESKY_PUBLISHING');
      case FeatureFlag.integratedApps:
        return const bool.fromEnvironment('FF_INTEGRATED_APPS');
      case FeatureFlag.accountSwitching:
        return const bool.fromEnvironment('FF_ACCOUNT_SWITCHING');
      case FeatureFlag.profileListFeatures:
        return const bool.fromEnvironment('FF_PROFILE_LIST_FEATURES');
      case FeatureFlag.videoReplies:
        const isReleaseBuild = bool.fromEnvironment('dart.vm.product');
        return const bool.fromEnvironment(
          'FF_VIDEO_REPLIES',
          defaultValue: !isReleaseBuild,
        );
      case FeatureFlag.advancedRelaySettings:
        return const bool.fromEnvironment('FF_ADVANCED_RELAY_SETTINGS');
      case FeatureFlag.publishDmRelayList:
        // Default OFF until the backend relay accepts kind-10050 (#4974 RC3).
        return const bool.fromEnvironment('FF_PUBLISH_DM_RELAY_LIST');
      case FeatureFlag.feedTuning:
        return const bool.fromEnvironment('FF_FEED_TUNING');
      case FeatureFlag.profileMonetizationLinks:
        return const bool.fromEnvironment('FF_PROFILE_MONETIZATION_LINKS');
      case FeatureFlag.lightMode:
        return const bool.fromEnvironment('FF_LIGHT_MODE');
      case FeatureFlag.adaptiveMediaChrome:
        return const bool.fromEnvironment('FF_ADAPTIVE_MEDIA_CHROME');
    }
  }

  /// Check if a flag has a default value defined
  bool hasDefault(FeatureFlag flag) {
    // All flags have defaults in our implementation
    return true;
  }

  /// Get the environment variable key for a flag
  String getEnvironmentKey(FeatureFlag flag) {
    switch (flag) {
      case FeatureFlag.enhancedAnalytics:
        return 'FF_ENHANCED_ANALYTICS';
      case FeatureFlag.debugTools:
        return 'FF_DEBUG_TOOLS';
      case FeatureFlag.curatedLists:
        return 'FF_CURATED_LISTS';
      case FeatureFlag.blueskyPublishing:
        return 'FF_BLUESKY_PUBLISHING';
      case FeatureFlag.integratedApps:
        return 'FF_INTEGRATED_APPS';
      case FeatureFlag.accountSwitching:
        return 'FF_ACCOUNT_SWITCHING';
      case FeatureFlag.profileListFeatures:
        return 'FF_PROFILE_LIST_FEATURES';
      case FeatureFlag.videoReplies:
        return 'FF_VIDEO_REPLIES';
      case FeatureFlag.advancedRelaySettings:
        return 'FF_ADVANCED_RELAY_SETTINGS';
      case FeatureFlag.publishDmRelayList:
        return 'FF_PUBLISH_DM_RELAY_LIST';
      case FeatureFlag.feedTuning:
        return 'FF_FEED_TUNING';
      case FeatureFlag.profileMonetizationLinks:
        return 'FF_PROFILE_MONETIZATION_LINKS';
      case FeatureFlag.lightMode:
        return 'FF_LIGHT_MODE';
      case FeatureFlag.adaptiveMediaChrome:
        return 'FF_ADAPTIVE_MEDIA_CHROME';
    }
  }
}
