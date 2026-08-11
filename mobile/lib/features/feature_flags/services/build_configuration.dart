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
        // TODO(#6649): Re-promote after divine-funnelcake#691 ships.
        return const bool.fromEnvironment('FF_FEED_TUNING');
      case FeatureFlag.profileMonetizationLinks:
        return const bool.fromEnvironment('FF_PROFILE_MONETIZATION_LINKS');
      case FeatureFlag.lightMode:
        return const bool.fromEnvironment('FF_LIGHT_MODE');
      case FeatureFlag.adaptiveMediaChrome:
        return const bool.fromEnvironment('FF_ADAPTIVE_MEDIA_CHROME');
      case FeatureFlag.communityContentWarnings:
        // Default OFF pending T&S sign-off on surfacing warnings from
        // unverified community votes (#4771).
        return const bool.fromEnvironment('FF_COMMUNITY_CONTENT_WARNINGS');
      case FeatureFlag.divineSupporters:
        // Default OFF: MVP exploration behind the flag until store products
        // are configured in App Store Connect and Google Play Console.
        return const bool.fromEnvironment('FF_DIVINE_SUPPORTERS');
      case FeatureFlag.newPostNotifications:
        // Default OFF until divine-push-service fans kind 34236 out to
        // d=notify subscribers. On without it, the bell publishes a
        // subscription no service reads.
        return const bool.fromEnvironment('FF_NEW_POST_NOTIFICATIONS');
      case FeatureFlag.clientSeenFiltering:
        return const bool.fromEnvironment(
          'FF_CLIENT_SEEN_FILTERING',
          defaultValue: true,
        );
      case FeatureFlag.videoCardPostDate:
        // Default OFF so the count-hiding rule can be previewed internally
        // and killed remotely before it reaches the pre-campaign release.
        return const bool.fromEnvironment('FF_VIDEO_CARD_POST_DATE');
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
      case FeatureFlag.communityContentWarnings:
        return 'FF_COMMUNITY_CONTENT_WARNINGS';
      case FeatureFlag.divineSupporters:
        return 'FF_DIVINE_SUPPORTERS';
      case FeatureFlag.newPostNotifications:
        return 'FF_NEW_POST_NOTIFICATIONS';
      case FeatureFlag.clientSeenFiltering:
        return 'FF_CLIENT_SEEN_FILTERING';
      case FeatureFlag.videoCardPostDate:
        return 'FF_VIDEO_CARD_POST_DATE';
    }
  }
}
