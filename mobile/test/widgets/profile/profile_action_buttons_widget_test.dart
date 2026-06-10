// ABOUTME: Tests for profile action button row composition and target gating
// ABOUTME: Verifies target-directed affordances are absent without explanation

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const viewerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late MockNostrClient nostrClient;

  setUp(() {
    followRepository = MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    nostrClient = createMockNostrService();

    when(() => nostrClient.publicKey).thenReturn(viewerPubkey);

    when(() => blocklistRepository.isBlocked(any())).thenReturn(false);
    when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);

    when(() => followRepository.followingPubkeys).thenReturn(const []);
    when(() => followRepository.followingStream).thenAnswer(
      (_) => Stream<List<String>>.value(const []),
    );
    when(() => followRepository.watchMyFollowingCached()).thenAnswer(
      (_) => Stream.value(
        const CacheResult.live(
          FollowingSnapshot(pubkeys: <String>[], count: 0),
        ),
      ),
    );
  });

  Widget buildWidget() {
    return testMaterialApp(
      home: Scaffold(
        body: ProfileActionButtons(
          userIdHex: targetPubkey,
          isOwnProfile: false,
          displayName: 'Target User',
          onMessageUser: () {},
          onShareProfile: (_) {},
        ),
      ),
      additionalOverrides: [
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
      ],
      mockFollowRepository: followRepository,
      mockNostrService: nostrClient,
    );
  }

  testWidgets(
    'hides follow and message actions when target cannot be targeted',
    (tester) async {
      when(() => blocklistRepository.hasBlockedUs(targetPubkey)).thenReturn(
        true,
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(DivineIconButton), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    },
  );

  testWidgets(
    'keeps share right-aligned when already following target cannot be targeted',
    (tester) async {
      when(() => blocklistRepository.hasBlockedUs(targetPubkey)).thenReturn(
        true,
      );
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn(const [targetPubkey]);
      when(() => followRepository.followingStream).thenAnswer(
        (_) => Stream<List<String>>.value(const [targetPubkey]),
      );
      when(() => followRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(pubkeys: [targetPubkey], count: 1),
          ),
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(DivineIconButton), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    },
  );
}
