// @generated from analytics/event-contract.yaml.
// Source contract commit: 687df20125fac8b8643892e7cfaefbd84606c83c
// DO NOT EDIT. Update the contract and run analytics/codegen/generate.py.
const String productAnalyticsContractCommit =
    '687df20125fac8b8643892e7cfaefbd84606c83c';
const int productAnalyticsSchemaVersion = 1;
const bool? productAnalyticsConsentDefaultEnabled = null;

enum ProductAnalyticsSource {
  mobile('mobile'),
  web('web');

  const ProductAnalyticsSource(this.wireName);
  final String wireName;
}

enum ProductAnalyticsPlatform {
  ios('ios'),
  android('android'),
  web('web');

  const ProductAnalyticsPlatform(this.wireName);
  final String wireName;
}

enum ProductAnalyticsConsentCategory {
  productAnalytics('product_analytics');

  const ProductAnalyticsConsentCategory(this.wireName);
  final String wireName;
}

enum ProductAnalyticsSurface {
  feed('feed'),
  following('following'),
  discovery('discovery'),
  profile('profile'),
  searchResults('search_results'),
  onboarding('onboarding'),
  registration('registration'),
  landing('landing'),
  notifications('notifications'),
  settings('settings'),
  unknown('unknown');

  const ProductAnalyticsSurface(this.wireName);
  final String wireName;
}

enum ProductAnalyticsPlaybackEndReason {
  ended('ended'),
  paused('paused'),
  navigation('navigation'),
  backgrounded('backgrounded'),
  error('error'),
  unknown('unknown');

  const ProductAnalyticsPlaybackEndReason(this.wireName);
  final String wireName;
}

enum ProductAnalyticsNavigationAction {
  open('open'),
  back('back'),
  tab('tab'),
  deepLink('deep_link'),
  cta('cta'),
  swipe('swipe'),
  unknown('unknown');

  const ProductAnalyticsNavigationAction(this.wireName);
  final String wireName;
}

enum ProductAnalyticsOnboardingFlow {
  accountSetup('account_setup'),
  viewerSetup('viewer_setup'),
  creatorSetup('creator_setup');

  const ProductAnalyticsOnboardingFlow(this.wireName);
  final String wireName;
}

enum ProductAnalyticsOnboardingStep {
  welcome('welcome'),
  identity('identity'),
  interests('interests'),
  followSuggestions('follow_suggestions'),
  notifications('notifications'),
  complete('complete');

  const ProductAnalyticsOnboardingStep(this.wireName);
  final String wireName;
}

enum ProductAnalyticsOnboardingResult {
  viewed('viewed'),
  completed('completed'),
  skipped('skipped'),
  failed('failed');

  const ProductAnalyticsOnboardingResult(this.wireName);
  final String wireName;
}

enum ProductAnalyticsOnboardingReason {
  none('none'),
  dismissed('dismissed'),
  validation('validation'),
  network('network'),
  unknown('unknown');

  const ProductAnalyticsOnboardingReason(this.wireName);
  final String wireName;
}

enum ProductAnalyticsAssignmentSource {
  client('client'),
  server('server');

  const ProductAnalyticsAssignmentSource(this.wireName);
  final String wireName;
}

enum ProductAnalyticsLandingPage {
  home('home'),
  download('download'),
  invite('invite'),
  registration('registration');

  const ProductAnalyticsLandingPage(this.wireName);
  final String wireName;
}

enum ProductAnalyticsReferrerClass {
  direct('direct'),
  search('search'),
  social('social'),
  referral('referral'),
  campaign('campaign'),
  unknown('unknown');

  const ProductAnalyticsReferrerClass(this.wireName);
  final String wireName;
}

enum ProductAnalyticsRegistrationEntryPoint {
  landing('landing'),
  invite('invite'),
  deepLink('deep_link'),
  downloadPrompt('download_prompt'),
  unknown('unknown');

  const ProductAnalyticsRegistrationEntryPoint(this.wireName);
  final String wireName;
}

class ProductAnalyticsEnvelope {
  const ProductAnalyticsEnvelope({
    required this.eventId,
    required this.schemaVersion,
    required this.occurredAt,
    required this.anonymousId,
    required this.sessionId,
    required this.source,
    required this.platform,
    required this.release,
    required this.consentCategory,
  });

  final String eventId;
  final int schemaVersion;
  final DateTime occurredAt;
  final String anonymousId;
  final String sessionId;
  final ProductAnalyticsSource source;
  final ProductAnalyticsPlatform platform;
  final String release;
  final ProductAnalyticsConsentCategory consentCategory;

  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'schema_version': schemaVersion,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'anonymous_id': anonymousId,
    'session_id': sessionId,
    'source': source.wireName,
    'platform': platform.wireName,
    'release': release,
    'consent_category': consentCategory.wireName,
  };
}

/// Wire event name: `content_impression_recorded`.
class ContentImpressionRecordedProperties {
  const ContentImpressionRecordedProperties({
    required this.contentId,
    required this.surface,
    required this.position,
    required this.visibleMs,
    this.recommendationId,
  });

  final String contentId;
  final ProductAnalyticsSurface surface;
  final int position;
  final int visibleMs;
  final String? recommendationId;

  Map<String, Object?> toJson() => {
    'content_id': contentId,
    'surface': surface.wireName,
    'position': position,
    'visible_ms': visibleMs,
    if (recommendationId != null) 'recommendation_id': recommendationId,
  };
}

/// Wire event name: `playback_session_recorded`.
class PlaybackSessionRecordedProperties {
  const PlaybackSessionRecordedProperties({
    required this.playbackSessionId,
    required this.contentId,
    required this.surface,
    required this.durationMs,
    required this.watchedMs,
    required this.loopCount,
    required this.completed,
    required this.endReason,
  });

  final String playbackSessionId;
  final String contentId;
  final ProductAnalyticsSurface surface;
  final int durationMs;
  final int watchedMs;
  final int loopCount;
  final bool completed;
  final ProductAnalyticsPlaybackEndReason endReason;

  Map<String, Object?> toJson() => {
    'playback_session_id': playbackSessionId,
    'content_id': contentId,
    'surface': surface.wireName,
    'duration_ms': durationMs,
    'watched_ms': watchedMs,
    'loop_count': loopCount,
    'completed': completed,
    'end_reason': endReason.wireName,
  };
}

/// Wire event name: `navigation_context_recorded`.
class NavigationContextRecordedProperties {
  const NavigationContextRecordedProperties({
    required this.fromSurface,
    required this.toSurface,
    required this.action,
    this.contentId,
    this.recommendationId,
  });

  final ProductAnalyticsSurface fromSurface;
  final ProductAnalyticsSurface toSurface;
  final ProductAnalyticsNavigationAction action;
  final String? contentId;
  final String? recommendationId;

  Map<String, Object?> toJson() => {
    'from_surface': fromSurface.wireName,
    'to_surface': toSurface.wireName,
    'action': action.wireName,
    if (contentId != null) 'content_id': contentId,
    if (recommendationId != null) 'recommendation_id': recommendationId,
  };
}

/// Wire event name: `onboarding_step_recorded`.
class OnboardingStepRecordedProperties {
  const OnboardingStepRecordedProperties({
    required this.flow,
    required this.step,
    required this.result,
    this.reason,
  });

  final ProductAnalyticsOnboardingFlow flow;
  final ProductAnalyticsOnboardingStep step;
  final ProductAnalyticsOnboardingResult result;
  final ProductAnalyticsOnboardingReason? reason;

  Map<String, Object?> toJson() => {
    'flow': flow.wireName,
    'step': step.wireName,
    'result': result.wireName,
    if (reason != null) 'reason': reason?.wireName,
  };
}

/// Wire event name: `experiment_exposure`.
class ExperimentExposureProperties {
  const ExperimentExposureProperties({
    required this.experimentKey,
    required this.variantKey,
    required this.assignmentSource,
  });

  final String experimentKey;
  final String variantKey;
  final ProductAnalyticsAssignmentSource assignmentSource;

  Map<String, Object?> toJson() => {
    'experiment_key': experimentKey,
    'variant_key': variantKey,
    'assignment_source': assignmentSource.wireName,
  };
}

/// Wire event name: `landing_viewed`.
class LandingViewedProperties {
  const LandingViewedProperties({
    required this.landingPage,
    required this.referrerClass,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
  });

  final ProductAnalyticsLandingPage landingPage;
  final ProductAnalyticsReferrerClass referrerClass;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;

  Map<String, Object?> toJson() => {
    'landing_page': landingPage.wireName,
    'referrer_class': referrerClass.wireName,
    if (utmSource != null) 'utm_source': utmSource,
    if (utmMedium != null) 'utm_medium': utmMedium,
    if (utmCampaign != null) 'utm_campaign': utmCampaign,
    if (utmContent != null) 'utm_content': utmContent,
  };
}

/// Wire event name: `registration_started`.
class RegistrationStartedProperties {
  const RegistrationStartedProperties({
    required this.entryPoint,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.utmContent,
  });

  final ProductAnalyticsRegistrationEntryPoint entryPoint;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? utmContent;

  Map<String, Object?> toJson() => {
    'entry_point': entryPoint.wireName,
    if (utmSource != null) 'utm_source': utmSource,
    if (utmMedium != null) 'utm_medium': utmMedium,
    if (utmCampaign != null) 'utm_campaign': utmCampaign,
    if (utmContent != null) 'utm_content': utmContent,
  };
}

sealed class ProductAnalyticsEvent {
  const ProductAnalyticsEvent({required this.envelope});

  final ProductAnalyticsEnvelope envelope;
  String get eventName;
  Map<String, Object?> get propertiesJson;

  Map<String, Object?> toJson() => {
    ...envelope.toJson(),
    'event_name': eventName,
    'properties': propertiesJson,
  };
}

final class ContentImpressionRecordedEvent extends ProductAnalyticsEvent {
  const ContentImpressionRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final ContentImpressionRecordedProperties properties;

  @override
  String get eventName => 'content_impression_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class PlaybackSessionRecordedEvent extends ProductAnalyticsEvent {
  const PlaybackSessionRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final PlaybackSessionRecordedProperties properties;

  @override
  String get eventName => 'playback_session_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class NavigationContextRecordedEvent extends ProductAnalyticsEvent {
  const NavigationContextRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final NavigationContextRecordedProperties properties;

  @override
  String get eventName => 'navigation_context_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class OnboardingStepRecordedEvent extends ProductAnalyticsEvent {
  const OnboardingStepRecordedEvent({
    required super.envelope,
    required this.properties,
  });

  final OnboardingStepRecordedProperties properties;

  @override
  String get eventName => 'onboarding_step_recorded';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class ExperimentExposureEvent extends ProductAnalyticsEvent {
  const ExperimentExposureEvent({
    required super.envelope,
    required this.properties,
  });

  final ExperimentExposureProperties properties;

  @override
  String get eventName => 'experiment_exposure';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class LandingViewedEvent extends ProductAnalyticsEvent {
  const LandingViewedEvent({required super.envelope, required this.properties});

  final LandingViewedProperties properties;

  @override
  String get eventName => 'landing_viewed';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}

final class RegistrationStartedEvent extends ProductAnalyticsEvent {
  const RegistrationStartedEvent({
    required super.envelope,
    required this.properties,
  });

  final RegistrationStartedProperties properties;

  @override
  String get eventName => 'registration_started';

  @override
  Map<String, Object?> get propertiesJson => properties.toJson();
}
