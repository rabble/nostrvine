// ABOUTME: Widget tests for OthersFollowingScreen loading behavior
// ABOUTME: Ensures retained following content stays visible during reloads

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/screens/following/others_following_screen.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const followingOne =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const followingTwo =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const currentUserPubkey =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  group(OthersFollowingScreen, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistService mockBlocklistService;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistService = _MockContentBlocklistService();
      mockNostrClient = _MockNostrClient();

      when(() => mockBlocklistService.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistService.isFollowSevered(any()),
      ).thenReturn(false);
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => Stream<List<String>>.value([]));
      when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);
    });

    testWidgets('keeps following tiles visible while a reload is pending', (
      tester,
    ) async {
      final reloadCompleter = Completer<List<nostr_sdk.Event>>();
      var queryCount = 0;

      when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) {
        queryCount++;
        if (queryCount == 1) {
          return Future.value([
            nostr_sdk.Event(
              targetPubkey,
              3,
              [
                ['p', followingOne],
                ['p', followingTwo],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          ]);
        }
        return reloadCompleter.future;
      });

      await tester.pumpWidget(
        testMaterialApp(
          home: const OthersFollowingScreen(
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

      expect(find.byType(UserProfileTile), findsNWidgets(2));

      final listContext = tester.element(find.byType(ListView));
      listContext.read<OthersFollowingBloc>().add(
        const OthersFollowingListLoadRequested(targetPubkey),
      );
      await tester.pump();

      expect(find.byType(UserProfileTile), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      reloadCompleter.complete(const []);
    });
  });
}
