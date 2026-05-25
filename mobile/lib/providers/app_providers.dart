// ABOUTME: Compatibility barrel re-exporting the feature-domain provider modules
// ABOUTME: Split out of the original monolith via #4506; consumers still import this

// TODO(#4339): Drop this compatibility barrel once consumers import the
// feature-domain provider modules directly.
export 'auth_providers.dart';
export 'moderation_providers.dart';
export 'nostr_apps_providers.dart';
export 'notifications_providers.dart';
export 'permissions_providers.dart';
export 'preferences_providers.dart';
export 'relay_providers.dart';
export 'repository_providers.dart';
export 'social_providers.dart';
export 'upload_media_providers.dart';
export 'video_providers.dart';
