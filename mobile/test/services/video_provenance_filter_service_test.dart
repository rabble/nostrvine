// ABOUTME: Pins the capture-verified-only preference and its default.
// ABOUTME: Defaulting this on would hide 13% of modern uploads on upgrade.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VideoProvenanceFilterService', () {
    test('defaults to disabled when no preference is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = VideoProvenanceFilterService(prefs);

      // Opt-in: enabling it by default would silently hide every upload
      // without a capture chain from users who never chose it.
      expect(service.showVerifiedOnly, isFalse);
    });

    test('respects an explicitly enabled preference', () async {
      SharedPreferences.setMockInitialValues({'show_verified_only': true});
      final prefs = await SharedPreferences.getInstance();

      final service = VideoProvenanceFilterService(prefs);

      expect(service.showVerifiedOnly, isTrue);
    });

    test('persists enabled state across reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = VideoProvenanceFilterService(prefs);

      await service.setShowVerifiedOnly(true);

      expect(VideoProvenanceFilterService(prefs).showVerifiedOnly, isTrue);
    });

    test('notifies listeners when the preference changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = VideoProvenanceFilterService(prefs);
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.setShowVerifiedOnly(true);
      await service.setShowVerifiedOnly(true); // no-op, same value

      expect(notifications, equals(1));
    });
  });
}
