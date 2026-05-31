// ABOUTME: User-preference Riverpod providers split from app_providers.dart
// ABOUTME: Each service is initialized on first read and kept alive for the app lifetime

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/audio_device_preference_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/hold_to_record_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_providers.g.dart';

final feedAspectRatioPreferenceServiceProvider =
    Provider<FeedAspectRatioPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return FeedAspectRatioPreferenceService(prefs);
    });

/// Audio sharing preference service for managing whether audio is available
/// for reuse by default. keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
AudioSharingPreferenceService audioSharingPreferenceService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AudioSharingPreferenceService(prefs);
}

final holdToRecordPreferenceServiceProvider =
    Provider<HoldToRecordPreferenceService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return HoldToRecordPreferenceService(prefs);
    });

/// Audio device preference service for managing the preferred input device
/// for recording on macOS. keepAlive ensures preference persists.
@Riverpod(keepAlive: true)
AudioDevicePreferenceService audioDevicePreferenceService(Ref ref) {
  final service = AudioDevicePreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Language preference service for managing the user's preferred content
/// language. Used for NIP-32 self-labeling on published video events.
/// keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
LanguagePreferenceService languagePreferenceService(Ref ref) {
  final service = LanguagePreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}
