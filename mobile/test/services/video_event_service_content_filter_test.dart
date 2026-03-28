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
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime(2025).millisecondsSinceEpoch,
    content: '',
    timestamp: DateTime(2025),
    sha256: sha256,
    vineId: vineId,
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
          ['l', 'violence', 'content-warning'],
          ['x', 'sha-violence'],
        ]);

        final result = videoEventService.filterVideoList([
          _createVideo(id: 'video-2', sha256: 'sha-violence'),
        ]);

        expect(result, hasLength(1));
        expect(result.single.contentWarningLabels, isEmpty);
        expect(result.single.warnLabels, equals(['violence']));
      },
    );

    test('applies trusted addressable labels to replaceable videos', () async {
      await seedModerationLabels([
        ['L', 'content-warning'],
        ['l', 'graphic-media', 'content-warning'],
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
      expect(result.single.warnLabels, equals(['graphic-media']));
    });
  });
}
