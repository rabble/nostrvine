import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

class _FakeLabelEvent extends Fake implements Event {
  _FakeLabelEvent({required this.pubkey, required this.tags});

  @override
  final String pubkey;

  @override
  final List<List<String>> tags;
}

const _testPubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

VideoEvent _createVideo({
  List<String> contentWarningLabels = const [],
  List<String> hashtags = const [],
  String? sha256,
  String? vineId,
  String pubkey = _testPubkey,
}) {
  return VideoEvent(
    id: 'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2',
    pubkey: pubkey,
    createdAt: DateTime(2025).millisecondsSinceEpoch,
    content: '',
    timestamp: DateTime(2025),
    contentWarningLabels: contentWarningLabels,
    hashtags: hashtags,
    sha256: sha256,
    vineId: vineId,
  );
}

void main() {
  group('createNsfwFilter', () {
    late AgeVerificationService ageService;
    late ContentFilterService contentFilterService;
    late _MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late ModerationLabelService moderationLabelService;

    Future<void> seedModerationLabels(List<List<String>> tags) async {
      when(() => mockNostrClient.queryEvents(any())).thenAnswer(
        (_) async => [
          _FakeLabelEvent(
            pubkey: moderationLabelService.divineModerationPubkeyHex,
            tags: tags,
          ),
        ],
      );

      await moderationLabelService.subscribeToLabeler(
        moderationLabelService.divineModerationPubkeyHex,
      );
    }

    setUpAll(() {
      registerFallbackValue(<Filter>[_FakeFilter()]);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ageService = AgeVerificationService();
      contentFilterService = ContentFilterService(
        ageVerificationService: ageService,
      );
      await contentFilterService.initialize();
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      moderationLabelService = ModerationLabelService(
        nostrClient: mockNostrClient,
        authService: mockAuthService,
        sharedPreferences: prefs,
      );
    });

    group('with default preferences', () {
      test('returns false for video without content labels or hashtags', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo();

        expect(filter(video), isFalse);
      });

      test('returns true for video with nudity label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['nudity']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with sexual label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['sexual']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with porn label', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['porn']);

        expect(filter(video), isTrue);
      });

      test('returns false for video with violence label (warn by default)', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['violence']);

        expect(filter(video), isFalse);
      });

      test('returns false for video with drugs label (show by default)', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['drugs']);

        expect(filter(video), isFalse);
      });
    });

    group('NSFW hashtag detection', () {
      test('returns true for video with #nsfw hashtag', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['nsfw']);

        expect(filter(video), isTrue);
      });

      test('returns true for video with #adult hashtag', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['adult']);

        expect(filter(video), isTrue);
      });

      test('returns true for case-insensitive #NSFW hashtag', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['NSFW']);

        expect(filter(video), isTrue);
      });

      test('returns false for unrelated hashtags', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(hashtags: ['funny', 'cats', 'viral']);

        expect(filter(video), isFalse);
      });
    });

    group('unrecognized content-warning labels', () {
      test('adds nudity fallback for unrecognized labels', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // 'some-unknown-label' is not in ContentLabel enum
        final video = _createVideo(
          contentWarningLabels: ['some-unknown-label'],
        );

        // Unrecognized labels trigger conservative nudity fallback → hide
        expect(filter(video), isTrue);
      });

      test('does not add nudity fallback when recognized label present', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
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

          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(contentWarningLabels: ['nudity']);

          expect(filter(video), isFalse);
        },
      );

      test('returns true for violence when user sets to hide', () async {
        await contentFilterService.setPreference(
          ContentLabel.violence,
          ContentFilterPreference.hide,
        );

        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final video = _createVideo(contentWarningLabels: ['violence']);

        expect(filter(video), isTrue);
      });
    });

    group('mixed labels', () {
      test('returns true when any label maps to hide', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // drugs=show, nudity=hide → most restrictive wins → hide
        final video = _createVideo(contentWarningLabels: ['drugs', 'nudity']);

        expect(filter(video), isTrue);
      });

      test('returns false when all labels map to warn or show', () {
        final filter = createNsfwFilter(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        // drugs=show, violence=warn → most restrictive is warn, not hide
        final video = _createVideo(contentWarningLabels: ['drugs', 'violence']);

        expect(filter(video), isFalse);
      });

      test(
        'does not double-add nudity when hashtag and label both present',
        () {
          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(
            contentWarningLabels: ['nudity'],
            hashtags: ['nsfw'],
          );

          // Should still filter (nudity=hide), no double-add issues
          expect(filter(video), isTrue);
        },
      );

      test(
        'returns true for replaceable video with trusted addressable label',
        () async {
          await seedModerationLabels([
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
            ['a', '34236:$_testPubkey:replaceable-video-d-tag'],
          ]);

          final filter = createNsfwFilter(
            contentFilterService,
            moderationLabelService: moderationLabelService,
          );
          final video = _createVideo(vineId: 'replaceable-video-d-tag');

          expect(filter(video), isTrue);
        },
      );
    });

    group('createNsfwWarnLabels', () {
      test('returns trusted hash-based warn labels', () async {
        await seedModerationLabels([
          ['L', 'content-warning'],
          ['l', 'violence', 'content-warning'],
          ['x', 'trusted-warning-hash'],
        ]);

        final resolver = createNsfwWarnLabels(
          contentFilterService,
          moderationLabelService: moderationLabelService,
        );
        final labels = resolver(
          _createVideo(sha256: 'trusted-warning-hash'),
        );

        expect(labels, equals(['violence']));
      });
    });
  });
}
