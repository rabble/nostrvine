// ABOUTME: Widget tests for OthersFollowersScreen startup behavior
// ABOUTME: Ensures the followers list renders without waiting for exact count

import 'dart:async';

import 'package:content_blocklist_service/content_blocklist_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/followers/others_followers_screen.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const followerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const currentUserPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  group(OthersFollowersScreen, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistService mockBlocklistService;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistService = _MockContentBlocklistService();
      mockNostrClient = _MockNostrClient();

      when(() => mockBlocklistService.isBlocked(any())).thenReturn(false);
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value([]));
      when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);
    });

    testWidgets(
      'renders follower tiles before the exact count request finishes',
      (tester) async {
        final followerCountCompleter = Completer<int>();

        when(
          () => mockFollowRepository.getFollowers(targetPubkey),
        ).thenAnswer((_) async => [followerPubkey]);
        when(
          () => mockFollowRepository.getFollowerCount(targetPubkey),
        ).thenAnswer((_) => followerCountCompleter.future);

        await tester.pumpWidget(
          testMaterialApp(
            home: const OthersFollowersScreen(
              pubkey: targetPubkey,
              displayName: 'Alice',
            ),
            mockProfileRepository: createMockProfileRepository(),
            mockNostrService: mockNostrClient,
            additionalOverrides: [
              followRepositoryProvider.overrideWithValue(mockFollowRepository),
              contentBlocklistServiceProvider.overrideWithValue(
                mockBlocklistService,
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(UserProfileTile), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        followerCountCompleter.complete(500);
      },
    );
  });
}
