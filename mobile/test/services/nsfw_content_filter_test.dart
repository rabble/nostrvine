import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _testPubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

VideoEvent _createVideo({
  List<String> contentWarningLabels = const [],
  List<String> hashtags = const [],
}) {
  return VideoEvent(
    id: 'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2',
    pubkey: _testPubkey,
    createdAt: DateTime(2025).millisecondsSinceEpoch,
    content: '',
    timestamp: DateTime(2025),
    contentWarningLabels: contentWarningLabels,
    hashtags: hashtags,
  );
}

void main() {
  group('createNsfwFilter', () {
    late AgeVerificationService ageService;
    late ContentFilterService contentFilterService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ageService = AgeVerificationService();
      contentFilterService = ContentFilterService(
        ageVerificationService: ageService,
      );
      await contentFilterService.initialize();
    });

    group('with default preferences', () {
      test('returns false for video without content labels or hashtags', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo();

        expect(filter(video), isFalse);
      });

      test('returns true for video with nudity label', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(contentWarningLabels: ['nudity']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with sexual label', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(contentWarningLabels: ['sexual']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with porn label', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(contentWarningLabels: ['porn']);

        expect(filter(video), isTrue);
      });

      test('returns false for video with violence label (warn by default)', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(contentWarningLabels: ['violence']);

        expect(filter(video), isFalse);
      });

      test('returns false for video with drugs label (show by default)', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(contentWarningLabels: ['drugs']);

        expect(filter(video), isFalse);
      });
    });

    group('NSFW hashtag detection', () {
      test('returns true for video with #nsfw hashtag', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(hashtags: ['nsfw']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with #adult hashtag', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(hashtags: ['adult']);

        expect(filter(video), isTrue);
      });

      test('returns true for case-insensitive #NSFW hashtag', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(hashtags: ['NSFW']);

        expect(filter(video), isTrue);
      });

      test('returns false for unrelated hashtags', () {
        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(hashtags: ['funny', 'cats', 'viral']);

        expect(filter(video), isFalse);
      });
    });

    group('unrecognized content-warning labels', () {
      test('adds nudity fallback for unrecognized labels', () {
        final filter = createNsfwFilter(contentFilterService);
        // 'some-unknown-label' is not in ContentLabel enum
        final video = _createVideo(
          contentWarningLabels: ['some-unknown-label'],
        );

        // Unrecognized labels trigger conservative nudity fallback → hide
        expect(filter(video), isTrue);
      });

      test('does not add nudity fallback when recognized label present', () {
        final filter = createNsfwFilter(contentFilterService);
        // 'drugs' is recognized and defaults to show
        final video = _createVideo(contentWarningLabels: ['drugs']);

        expect(filter(video), isFalse);
      });
    });

    group('with changed preferences', () {
      test(
        'returns false for nudity when age-verified user sets to show',
        () async {
          await ageService.initialize();
          await ageService.setAdultContentVerified(true);
          await contentFilterService.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );

          final filter = createNsfwFilter(contentFilterService);
          final video = _createVideo(contentWarningLabels: ['nudity']);

          expect(filter(video), isFalse);
        },
      );

      test('returns true for violence when user sets to hide', () async {
        await contentFilterService.setPreference(
          ContentLabel.violence,
          ContentFilterPreference.hide,
        );

        final filter = createNsfwFilter(contentFilterService);
        final video = _createVideo(contentWarningLabels: ['violence']);

        expect(filter(video), isTrue);
      });
    });

    group('mixed labels', () {
      test('returns true when any label maps to hide', () {
        final filter = createNsfwFilter(contentFilterService);
        // drugs=show, nudity=hide → most restrictive wins → hide
        final video = _createVideo(contentWarningLabels: ['drugs', 'nudity']);

        expect(filter(video), isTrue);
      });

      test('returns false when all labels map to warn or show', () {
        final filter = createNsfwFilter(contentFilterService);
        // drugs=show, violence=warn → most restrictive is warn, not hide
        final video = _createVideo(contentWarningLabels: ['drugs', 'violence']);

        expect(filter(video), isFalse);
      });

      test(
        'does not double-add nudity when hashtag and label both present',
        () {
          final filter = createNsfwFilter(contentFilterService);
          final video = _createVideo(
            contentWarningLabels: ['nudity'],
            hashtags: ['nsfw'],
          );

          // Should still filter (nudity=hide), no double-add issues
          expect(filter(video), isTrue);
        },
      );
    });
  });
}
