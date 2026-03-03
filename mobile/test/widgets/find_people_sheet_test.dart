// ABOUTME: Tests for FindPeopleSheet widget
// ABOUTME: Validates rendering, search states, user selection, and hasVideos
// ABOUTME: regression guard

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:profile_repository/profile_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group(FindPeopleSheet, () {
    late _MockProfileRepository mockProfileRepo;
    late _MockFollowRepository mockFollowRepo;
    late MockUserProfileService mockUserProfileService;

    setUp(() {
      mockProfileRepo = _MockProfileRepository();
      mockFollowRepo = _MockFollowRepository();
      mockUserProfileService = createMockUserProfileService();

      // Default stubs
      when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
    });

    Widget createTestWidget() {
      return testMaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<ShareableUser>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const FindPeopleSheet(),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            );
          },
        ),
        mockUserProfileService: mockUserProfileService,
        additionalOverrides: [
          profileRepositoryProvider.overrideWithValue(mockProfileRepo),
          followRepositoryProvider.overrideWithValue(mockFollowRepo),
        ],
      );
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
    }

    group('rendering', () {
      testWidgets(
        'renders search field with "Find people" hint text',
        (tester) async {
          await openSheet(tester);

          expect(find.byType(TextField), findsOneWidget);
          expect(find.text('Find people'), findsOneWidget);
        },
      );

      testWidgets(
        'renders "No contacts found" when follow list is empty',
        (tester) async {
          await openSheet(tester);

          expect(
            find.text(
              'No contacts found.\nStart following people to see them here.',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('renders contact list when contacts are loaded', (
        tester,
      ) async {
        final pubkey = 'a' * 64;
        when(() => mockFollowRepo.followingPubkeys).thenReturn([pubkey]);
        when(
          () => mockUserProfileService.hasProfile(pubkey),
        ).thenReturn(true);
        when(
          () => mockUserProfileService.getCachedProfile(pubkey),
        ).thenReturn(
          UserProfile(
            pubkey: pubkey,
            displayName: 'Alice',
            createdAt: DateTime.now(),
            eventId: 'event-$pubkey',
            rawData: const {'display_name': 'Alice'},
          ),
        );

        await openSheet(tester);

        expect(find.text('Alice'), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
      });
    });

    group('search states', () {
      testWidgets(
        'shows loading indicator when search is in progress',
        (tester) async {
          // Use a completer to control when the search completes
          final completer = Completer<List<UserProfile>>();
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => completer.future);

          await openSheet(tester);

          // Type a search query
          await tester.enterText(find.byType(TextField), 'alice');
          // Wait for debounce (300ms) + some processing
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          // Complete the future to avoid pending timer errors
          completer.complete([]);
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'shows search results when search succeeds with results',
        (tester) async {
          final pubkey = 'b' * 64;
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: pubkey,
                displayName: 'Bob',
                picture: 'https://example.com/bob.jpg',
                createdAt: DateTime.now(),
                eventId: 'event-$pubkey',
                rawData: const {'display_name': 'Bob'},
              ),
            ],
          );

          await openSheet(tester);

          await tester.enterText(find.byType(TextField), 'bob');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          expect(find.text('Bob'), findsOneWidget);
        },
      );

      testWidgets(
        'shows "No users found" when search succeeds with empty results',
        (tester) async {
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);

          await openSheet(tester);

          await tester.enterText(find.byType(TextField), 'nonexistent');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          expect(find.text('No users found'), findsOneWidget);
        },
      );

      testWidgets(
        'shows "Search failed" when search fails',
        (tester) async {
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('Network error'));

          await openSheet(tester);

          await tester.enterText(find.byType(TextField), 'error');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          expect(
            find.text('Search failed. Please try again.'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'returns to contact list when search is cleared',
        (tester) async {
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);

          await openSheet(tester);

          // Type something
          await tester.enterText(find.byType(TextField), 'test');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          expect(find.text('No users found'), findsOneWidget);

          // Clear the search
          await tester.enterText(find.byType(TextField), '');
          await tester.pumpAndSettle();

          // Should return to contacts (empty state in this case)
          expect(
            find.text(
              'No contacts found.\nStart following people to see them here.',
            ),
            findsOneWidget,
          );
        },
      );
    });

    group('integration', () {
      testWidgets(
        'creates UserSearchBloc with hasVideos: false (regression guard)',
        (tester) async {
          when(
            () => mockProfileRepo.searchUsers(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => []);

          await openSheet(tester);

          // Type a search query to trigger the bloc
          await tester.enterText(find.byType(TextField), 'test');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          // Verify searchUsers was called WITHOUT hasVideos parameter
          // (hasVideos: false means the parameter is not passed to the API)
          verify(
            () => mockProfileRepo.searchUsers(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );
    });
  });
}
