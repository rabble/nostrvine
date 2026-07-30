// ABOUTME: Tests for profile action button row composition and target gating
// ABOUTME: Verifies target-directed affordances are absent without explanation

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_notify_bell_button.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNotifySubscriptionsRepository extends Mock
    implements NotifySubscriptionsRepository {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const viewerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late MockNostrClient nostrClient;
  late _MockNotifySubscriptionsRepository notifyRepository;
  late StreamController<Set<String>> notifySubscriptions;

  setUp(() {
    notifyRepository = _MockNotifySubscriptionsRepository();
    notifySubscriptions = StreamController<Set<String>>.broadcast();
    when(
      () => notifyRepository.watchSubscriptions(
        ownerPubkey: any(named: 'ownerPubkey'),
      ),
    ).thenAnswer((_) => notifySubscriptions.stream);
    when(
      () => notifyRepository.subscribe(
        ownerPubkey: any(named: 'ownerPubkey'),
        creatorPubkey: any(named: 'creatorPubkey'),
      ),
    ).thenAnswer(
      (_) async => const PeopleListPublishResult.submitted(eventId: 'e1'),
    );
    when(
      () => notifyRepository.unsubscribe(
        ownerPubkey: any(named: 'ownerPubkey'),
        creatorPubkey: any(named: 'creatorPubkey'),
      ),
    ).thenAnswer(
      (_) async => const PeopleListPublishResult.submitted(eventId: 'e1'),
    );
    followRepository = MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    nostrClient = createMockNostrService();

    when(() => nostrClient.publicKey).thenReturn(viewerPubkey);

    when(() => blocklistRepository.isBlocked(any())).thenReturn(false);
    when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
    when(
      () => blocklistRepository.currentState,
    ).thenReturn(ContentPolicyState.empty());

    when(() => followRepository.followingPubkeys).thenReturn(const []);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => Stream<List<String>>.value(const []));
    when(() => followRepository.watchMyFollowingCached()).thenAnswer(
      (_) => Stream.value(
        const CacheResult.live(
          FollowingSnapshot(pubkeys: <String>[], count: 0),
        ),
      ),
    );
  });

  tearDown(() async {
    await notifySubscriptions.close();
  });

  Widget buildWidget({bool isMessageRestricted = false}) {
    return testMaterialApp(
      home: Scaffold(
        body: ProfileActionButtons(
          userIdHex: targetPubkey,
          isOwnProfile: false,
          displayName: 'Target User',
          onMessageUser: () {},
          isMessageRestricted: isMessageRestricted,
          onShareProfile: (_) {},
        ),
      ),
      additionalOverrides: [
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        notifySubscriptionsRepositoryProvider.overrideWithValue(
          notifyRepository,
        ),
      ],
      mockFollowRepository: followRepository,
      mockNostrService: nostrClient,
    );
  }

  testWidgets(
    'hides follow and message actions when target cannot be targeted',
    (tester) async {
      when(
        () => blocklistRepository.hasBlockedUs(targetPubkey),
      ).thenReturn(true);
      when(() => blocklistRepository.currentState).thenReturn(
        const ContentPolicyState(
          currentUserPubkey: viewerPubkey,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {targetPubkey},
          pubkeysMutingUs: {},
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

  testWidgets(
    'keeps share right-aligned when already following target cannot be targeted',
    (tester) async {
      when(
        () => blocklistRepository.hasBlockedUs(targetPubkey),
      ).thenReturn(true);
      when(() => blocklistRepository.currentState).thenReturn(
        const ContentPolicyState(
          currentUserPubkey: viewerPubkey,
          mutedPubkeys: {},
          blockedPubkeys: {},
          pubkeysBlockingUs: {targetPubkey},
          pubkeysMutingUs: {},
        ),
      );
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn(const [targetPubkey]);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value(const [targetPubkey]));
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

  testWidgets('hides only message action when DM policy restricts the viewer', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget(isMessageRestricted: true));
    await tester.pump();

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
    expect(find.byType(DivineButton), findsOneWidget);
    expect(find.byType(DivineIconButton), findsOneWidget);
  });

  group('notification bell', () {
    late StreamController<List<String>> followingStream;

    setUp(() {
      followingStream = StreamController<List<String>>.broadcast();
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => followingStream.stream);
    });

    tearDown(() async {
      await followingStream.close();
    });

    void followingTarget() {
      when(
        () => followRepository.followingPubkeys,
      ).thenReturn(const [targetPubkey]);
      when(() => followRepository.watchMyFollowingCached()).thenAnswer(
        (_) => Stream.value(
          const CacheResult.live(
            FollowingSnapshot(pubkeys: [targetPubkey], count: 1),
          ),
        ),
      );
    }

    testWidgets('is absent when the viewer does not follow the target', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileNotifyBellButton), findsNothing);
    });

    testWidgets('appears once the viewer follows the target', (tester) async {
      followingTarget();

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileNotifyBellButton), findsOneWidget);
    });

    testWidgets('tapping it subscribes the viewer to the target', (
      tester,
    ) async {
      followingTarget();

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // The real repository hands out a seeded BehaviorSubject; the bell is
      // deliberately inert until that first emission arrives.
      notifySubscriptions.add(const <String>{});
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ProfileNotifyBellButton));
      await tester.pumpAndSettle();

      verify(
        () => notifyRepository.subscribe(
          ownerPubkey: viewerPubkey,
          creatorPubkey: targetPubkey,
        ),
      ).called(1);
    });

    testWidgets('unfollowing clears the subscription', (tester) async {
      followingTarget();

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ProfileNotifyBellButton), findsOneWidget);

      // The bell unmounts the moment the row flips to not-following, so the
      // teardown has to be driven from a host above it.
      when(() => followRepository.followingPubkeys).thenReturn(const []);
      followingStream.add(const <String>[]);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileNotifyBellButton), findsNothing);
      verify(
        () => notifyRepository.unsubscribe(
          ownerPubkey: viewerPubkey,
          creatorPubkey: targetPubkey,
        ),
      ).called(1);
    });
  });
}
