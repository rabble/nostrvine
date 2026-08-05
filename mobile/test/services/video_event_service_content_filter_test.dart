import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

class _FakeLabelEvent extends Fake implements Event {
  _FakeLabelEvent({required this.pubkey, required this.tags});

  @override
  final String pubkey;

  @override
  final List<List<String>> tags;
}

VideoEvent _createVideo({
  required String id,
  String pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111',
  String? sha256,
  String? vineId,
  List<String> contentWarningLabels = const [],
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime(2025).millisecondsSinceEpoch,
    content: '',
    timestamp: DateTime(2025),
    sha256: sha256,
    vineId: vineId,
    addressableDTag: vineId,
    contentWarningLabels: contentWarningLabels,
  );
}

void main() {
  late _MockNostrClient mockNostrClient;
  late _MockSubscriptionManager mockSubscriptionManager;
  late _MockAuthService mockAuthService;
  late VideoEventService videoEventService;
  late ModerationLabelService moderationLabelService;
  late ContentFilterService contentFilterService;
  late AgeVerificationService ageVerificationService;

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
    mockNostrClient = _MockNostrClient();
    mockSubscriptionManager = _MockSubscriptionManager();
    mockAuthService = _MockAuthService();

    ageVerificationService = AgeVerificationService();
    await ageVerificationService.initialize();
    contentFilterService = ContentFilterService(
      ageVerificationService: ageVerificationService,
    );
    await contentFilterService.initialize();

    moderationLabelService = ModerationLabelService(
      nostrClient: mockNostrClient,
      authService: mockAuthService,
      sharedPreferences: prefs,
    );

    videoEventService = VideoEventService(
      mockNostrClient,
      subscriptionManager: mockSubscriptionManager,
    );
    videoEventService.setContentFilterService(contentFilterService);
    videoEventService.setModerationLabelService(moderationLabelService);
  });

  group('VideoEventService content filter integration', () {
    test('hides videos labeled via trusted kind-1985 event labels', () async {
      await seedModerationLabels([
        ['L', 'content-warning'],
        ['l', 'nudity', 'content-warning'],
        ['e', 'video-1'],
      ]);

      final result = videoEventService.filterVideoList([
        _createVideo(id: 'video-1'),
      ]);

      expect(result, isEmpty);
    });

    test(
      'applies warn labels from trusted hash-based kind-1985 labels',
      () async {
        await seedModerationLabels([
          ['L', 'content-warning'],
          ['l', 'flashing-lights', 'content-warning'],
          ['x', 'sha-flashing-lights'],
        ]);

        final result = videoEventService.filterVideoList([
          _createVideo(id: 'video-2', sha256: 'sha-flashing-lights'),
        ]);

        expect(result, hasLength(1));
        expect(result.single.contentWarningLabels, isEmpty);
        expect(result.single.warnLabels, equals(['flashing-lights']));
      },
    );

    test('applies trusted addressable labels to replaceable videos', () async {
      await seedModerationLabels([
        ['L', 'content-warning'],
        ['l', 'flashing-lights', 'content-warning'],
        ['a', '34236:creator_pubkey_hex:replaceable-video-d-tag'],
      ]);

      final result = videoEventService.filterVideoList([
        _createVideo(
          id: 'video-3',
          pubkey: 'creator_pubkey_hex',
          vineId: 'replaceable-video-d-tag',
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.contentWarningLabels, isEmpty);
      expect(result.single.warnLabels, equals(['flashing-lights']));
    });
  });

  group('creator self-labels (#5062)', () {
    final nonAdultAgeRestrictedLabels = ContentFilterService
        .ageRestrictedCategories
        .where((label) => !ContentFilterService.adultCategories.contains(label))
        .toList();

    test('a self-labeled warn-category video stays visible behind the overlay '
        'for a non-age-verified viewer', () async {
      expect(ageVerificationService.isAdultContentVerified, isFalse);

      // flashing-lights is a warn category, not age-gated: the creator's
      // self-label must keep the video visible (behind the overlay), not
      // make it disappear. This is the reported behaviour in #5062.
      final result = videoEventService.filterVideoList([
        _createVideo(
          id: 'video-flashing',
          contentWarningLabels: const ['flashing-lights'],
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.warnLabels, equals(['flashing-lights']));
    });

    test('self-labeled non-adult age-restricted videos are hidden for '
        'non-age-verified viewers', () async {
      expect(ageVerificationService.isAdultContentVerified, isFalse);

      for (final label in nonAdultAgeRestrictedLabels) {
        final result = videoEventService.filterVideoList([
          _createVideo(
            id: 'video-${label.value}',
            contentWarningLabels: [label.value],
          ),
        ]);

        expect(
          result,
          isEmpty,
          reason:
              '${label.value} should stay hidden for non-age-verified '
              'viewers even when applied as a creator self-label.',
        );
      }
    });

    test('self-labeled non-adult age-restricted videos become visible behind '
        'the overlay once the viewer is age-verified', () async {
      await ageVerificationService.setAdultContentVerified(true);

      for (final label in nonAdultAgeRestrictedLabels) {
        final result = videoEventService.filterVideoList([
          _createVideo(
            id: 'video-${label.value}-verified',
            contentWarningLabels: [label.value],
          ),
        ]);

        expect(
          result,
          hasLength(1),
          reason: '${label.value} should be visible after age verification.',
        );
        expect(result.single.warnLabels, equals([label.value]));
      }
    });
  });
}
