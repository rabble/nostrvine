// ABOUTME: Tests for FeatureFlag enum defining available feature flags
// ABOUTME: Validates enum properties, uniqueness, and metadata consistency

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

void main() {
  group('FeatureFlag enum', () {
    test('should have display names', () {
      expect(FeatureFlag.newCameraUI.displayName, equals('New Camera UI'));
      expect(FeatureFlag.debugTools.displayName, equals('Debug Tools'));
    });

    test('should have descriptions', () {
      expect(FeatureFlag.newCameraUI.description, isNotEmpty);
      expect(FeatureFlag.debugTools.description, isNotEmpty);
    });

    test('should have unique names', () {
      final names = FeatureFlag.values.map((f) => f.name).toSet();
      expect(names.length, equals(FeatureFlag.values.length));
    });

    test('should have unique display names', () {
      final displayNames = FeatureFlag.values.map((f) => f.displayName).toSet();
      expect(displayNames.length, equals(FeatureFlag.values.length));
    });

    test('should include expected flags for OpenVine', () {
      expect(FeatureFlag.values, contains(FeatureFlag.newCameraUI));
      expect(FeatureFlag.values, contains(FeatureFlag.accountSwitching));
      expect(FeatureFlag.values, contains(FeatureFlag.enhancedAnalytics));
      expect(FeatureFlag.values, contains(FeatureFlag.newProfileLayout));
      expect(FeatureFlag.values, contains(FeatureFlag.livestreamingBeta));
      expect(FeatureFlag.values, contains(FeatureFlag.liveDiscovery));
      expect(FeatureFlag.values, contains(FeatureFlag.liveAudience));
      expect(FeatureFlag.values, contains(FeatureFlag.liveHost));
      expect(
        FeatureFlag.values,
        contains(FeatureFlag.liveSpeakerPublishing),
      );
      expect(FeatureFlag.values, contains(FeatureFlag.debugTools));
      expect(FeatureFlag.values, contains(FeatureFlag.integratedApps));
      expect(FeatureFlag.values, contains(FeatureFlag.videoReplies));
    });

    test('live flags should have correct metadata', () {
      expect(FeatureFlag.liveDiscovery.displayName, equals('Live Discovery'));
      expect(
        FeatureFlag.liveDiscovery.description,
        equals('Enable public live room discovery surfaces'),
      );

      expect(FeatureFlag.liveAudience.displayName, equals('Live Audience'));
      expect(
        FeatureFlag.liveAudience.description,
        equals('Enable native room join and audience playback'),
      );

      expect(FeatureFlag.liveHost.displayName, equals('Live Host'));
      expect(
        FeatureFlag.liveHost.description,
        equals('Enable room creation and host controls'),
      );

      expect(
        FeatureFlag.liveSpeakerPublishing.displayName,
        equals('Live Speaker Publishing'),
      );
      expect(
        FeatureFlag.liveSpeakerPublishing.description,
        equals(
          'Enable invited speakers to publish camera and microphone in live rooms',
        ),
      );
    });

    test('integratedApps flag should have correct metadata', () {
      expect(FeatureFlag.integratedApps.displayName, equals('Integrated Apps'));
      expect(FeatureFlag.integratedApps.description, isNotEmpty);
      expect(FeatureFlag.integratedApps.description.length, greaterThan(10));
    });

    test('should provide meaningful descriptions', () {
      for (final flag in FeatureFlag.values) {
        expect(
          flag.description.length,
          greaterThan(10),
          reason: 'Flag ${flag.name} should have meaningful description',
        );
      }
    });
  });
}
