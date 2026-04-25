// ABOUTME: Tests for UserPickerSheet widget
// ABOUTME: Verifies search functionality, local follow search, and user selection

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Mock for ProfileRepository
class _MockProfileRepository extends Mock implements ProfileRepository {}

/// Mock for FollowRepository
class _MockFollowRepository extends Mock implements FollowRepository {}

/// Create a mock ProfileRepository
_MockProfileRepository _createMockProfileRepository({
  List<UserProfile> searchResults = const [],
  List<UserProfile> cachedProfiles = const [],
}) {
  final mock = _MockProfileRepository();

  // Mock searchUsersProgressive (used by UserSearchBloc)
  when(
    () => mock.searchUsersProgressive(
      query: any(named: 'query'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      sortBy: any(named: 'sortBy'),
      hasVideos: any(named: 'hasVideos'),
      boostPubkeys: any(named: 'boostPubkeys'),
    ),
  ).thenAnswer((_) => Stream.value(searchResults));

  // Mock getCachedProfile
  for (final profile in cachedProfiles) {
    when(
      () => mock.getCachedProfile(pubkey: profile.pubkey),
    ).thenAnswer((_) async => profile);
  }

  // Default for unknown pubkeys
  when(
    () => mock.getCachedProfile(pubkey: any(named: 'pubkey')),
  ).thenAnswer((_) async => null);

  return mock;
}

/// Create a mock FollowRepository
_MockFollowRepository _createMockFollowRepository({
  List<String> followingPubkeys = const [],
}) {
  final mock = _MockFollowRepository();
  when(() => mock.followingPubkeys).thenReturn(followingPubkeys);
  when(() => mock.followingStream).thenAnswer(
    (_) => BehaviorSubject<List<String>>.seeded(followingPubkeys).stream,
  );
  when(() => mock.isInitialized).thenReturn(true);
  when(() => mock.followingCount).thenReturn(followingPubkeys.length);
  return mock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(UserPickerSheet, () {
    group('renders', () {
      testWidgets('search text field', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('search icon in text field', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('"Type a name to search" hint for allUsers mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Type a name to search'), findsOneWidget);
      });
    });

    group('mutualFollowsOnly mode', () {
      testWidgets('shows loading indicator initially', (tester) async {
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: ['pubkey1'],
        );

        final mockProfileRepo = _createMockProfileRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        // Should show loading while follow profiles load
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows empty state when no follows exist', (tester) async {
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show empty follow list message
        expect(find.text('Your crew is out there'), findsOneWidget);
      });

      testWidgets('shows "Go back" button in empty state', (tester) async {
        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Go back'), findsOneWidget);
      });

      testWidgets('displays follow list after loading', (tester) async {
        final followPubkeys = ['pubkey1', 'pubkey2'];
        final profiles = [
          UserProfile(
            pubkey: 'pubkey1',
            name: 'User One',
            rawData: const {'name': 'User One'},
            createdAt: DateTime.now(),
            eventId: 'event1',
          ),
          UserProfile(
            pubkey: 'pubkey2',
            name: 'User Two',
            rawData: const {'name': 'User Two'},
            createdAt: DateTime.now(),
            eventId: 'event2',
          ),
        ];

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: followPubkeys,
        );

        final mockProfileRepo = _createMockProfileRepository(
          cachedProfiles: profiles,
        );

        // Explicitly stub each pubkey
        for (final profile in profiles) {
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: profile.pubkey),
          ).thenAnswer((_) async => profile);
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should not show empty state
        expect(find.text('Your crew is out there'), findsNothing);
      });

      testWidgets(
        'displays "Filter by name..." hint for mutualFollowsOnly mode',
        (tester) async {
          final followPubkeys = ['pubkey1'];
          final profiles = [
            UserProfile(
              pubkey: 'pubkey1',
              name: 'User One',
              rawData: const {'name': 'User One'},
              createdAt: DateTime.now(),
              eventId: 'event1',
            ),
          ];

          final mockFollowRepo = _createMockFollowRepository(
            followingPubkeys: followPubkeys,
          );

          final mockProfileRepo = _createMockProfileRepository();
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'pubkey1'),
          ).thenAnswer((_) async => profiles.first);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                followRepositoryProvider.overrideWithValue(mockFollowRepo),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Check for hint text in TextField
          final textField = tester.widget<TextField>(find.byType(TextField));
          expect(textField.decoration?.hintText, equals('Filter by name...'));
        },
      );
    });

    group('allUsers mode', () {
      testWidgets('shows hint text initially', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should display hint to type a name
        expect(find.text('Type a name to search'), findsOneWidget);
      });

      testWidgets('displays "Search by name..." hint text', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        // Check for hint text in TextField
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, equals('Search by name...'));
      });

      testWidgets(
        'renders tiles during progressive loading '
        'instead of the full-screen spinner',
        (tester) async {
          // Stream controller kept open after the first yield — this
          // simulates the real progressive search still running (e.g.
          // NIP-50 WebSocket phase) while the REST phase has already
          // delivered results.
          final streamController =
              StreamController<List<UserProfile>>.broadcast();
          addTearDown(streamController.close);

          final alice = UserProfile(
            pubkey: 'p_alice',
            name: 'Alice',
            rawData: const {'name': 'Alice'},
            createdAt: DateTime.now(),
            eventId: 'event_alice',
          );
          final mockProfileRepo = _createMockProfileRepository();
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => streamController.stream);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                followRepositoryProvider.overrideWithValue(
                  _createMockFollowRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'alice');
          // Past the 300ms search debounce.
          await tester.pump(const Duration(milliseconds: 400));

          // Emit the first batch — stream stays open, so the BLoC
          // stays in `loading` with results available. The fix is that
          // the picker now renders these results instead of a spinner.
          streamController.add([alice]);
          await tester.pump();

          // The tile renders while the stream is still open (loading). Before
          // the fix, the UI showed a full-screen spinner and Alice never
          // appeared until the progressive stream completed.
          expect(find.text('Alice'), findsOneWidget);
          // Only the footer load-more spinner should be in the tree (1);
          // before the fix there was a full-screen spinner instead (also 1),
          // so we distinguish by asserting the tile is present above.
        },
      );

      testWidgets(
        'boosts followed users above non-followed in search results',
        (tester) async {
          final zoe = UserProfile(
            pubkey: 'p_zoe',
            name: 'Zoe',
            rawData: const {'name': 'Zoe'},
            createdAt: DateTime.now(),
            eventId: 'event_zoe',
          );
          final liz = UserProfile(
            pubkey: 'p_liz',
            name: 'Liz Sweigart',
            rawData: const {'name': 'Liz Sweigart'},
            createdAt: DateTime.now(),
            eventId: 'event_liz',
          );
          final mockProfileRepo = _MockProfileRepository();
          // Simulate the real repository's boost behaviour: profiles whose
          // pubkey is in [boostPubkeys] are promoted to the front while
          // preserving server-relative order. Boost ordering itself is
          // unit-tested in profile_repository_test.dart; here we just need
          // a mock that reacts to [boostPubkeys] so the widget test can
          // assert that the UI reflects it.
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((invocation) {
            final boost =
                invocation.namedArguments[#boostPubkeys] as Set<String>? ??
                const <String>{};
            final results = [zoe, liz];
            if (boost.isEmpty) return Stream.value(results);
            final boosted = <UserProfile>[];
            final rest = <UserProfile>[];
            for (final p in results) {
              if (boost.contains(p.pubkey)) {
                boosted.add(p);
              } else {
                rest.add(p);
              }
            }
            return Stream.value([...boosted, ...rest]);
          });
          when(
            () => mockProfileRepo.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          final mockFollowRepo = _createMockFollowRepository(
            followingPubkeys: ['p_liz'],
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                followRepositoryProvider.overrideWithValue(mockFollowRepo),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          await tester.enterText(find.byType(TextField), 'liz');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          final lizTile = find.text('Liz Sweigart');
          final zoeTile = find.text('Zoe');
          expect(lizTile, findsOneWidget);
          expect(zoeTile, findsOneWidget);

          final lizY = tester.getTopLeft(lizTile).dy;
          final zoeY = tester.getTopLeft(zoeTile).dy;
          expect(
            lizY,
            lessThan(zoeY),
            reason: 'Followed user should render above non-followed user',
          );
        },
      );

      testWidgets(
        'disables iOS autocorrect and predictive suggestions on the '
        'search field',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(
                  _createMockProfileRepository(),
                ),
                followRepositoryProvider.overrideWithValue(
                  _createMockFollowRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          expect(
            textField.autocorrect,
            isFalse,
            reason: 'autocorrect must be off or iOS silently rewrites queries',
          );
          expect(
            textField.enableSuggestions,
            isFalse,
            reason: 'enableSuggestions must be off for the same reason',
          );
        },
      );

      testWidgets(
        'preserves previous results while a new query is loading',
        (tester) async {
          final alice = UserProfile(
            pubkey: 'p_alice',
            name: 'Alice',
            rawData: const {'name': 'Alice'},
            createdAt: DateTime.now(),
            eventId: 'event_alice',
          );
          final bob = UserProfile(
            pubkey: 'p_bob',
            name: 'Bob',
            rawData: const {'name': 'Bob'},
            createdAt: DateTime.now(),
            eventId: 'event_bob',
          );
          final bobController = StreamController<List<UserProfile>>.broadcast();
          addTearDown(bobController.close);

          final mockProfileRepo = _createMockProfileRepository();
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => Stream.value([alice]));
          when(
            () => mockProfileRepo.searchUsersProgressive(
              query: 'bob',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
              boostPubkeys: any(named: 'boostPubkeys'),
            ),
          ).thenAnswer((_) => bobController.stream);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(mockProfileRepo),
                followRepositoryProvider.overrideWithValue(
                  _createMockFollowRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          // First query — 'alice' succeeds.
          await tester.enterText(find.byType(TextField), 'alice');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(find.text('Alice'), findsOneWidget);

          // Second query — 'bob' starts loading (stream stays open).
          await tester.enterText(find.byType(TextField), 'bob');
          await tester.pump(const Duration(milliseconds: 400));

          // Alice is still visible — we did NOT blank the list.
          expect(find.text('Alice'), findsOneWidget);

          // When 'bob' results arrive, the list updates in place.
          bobController.add([bob]);
          // Pump twice: once to let the stream event propagate through the
          // bloc's emit.forEach, once more for the rebuilt BlocBuilder.
          await tester.pump();
          await tester.pump();
          expect(find.text('Bob'), findsOneWidget);
        },
      );
    });

    group('autoFocus', () {
      testWidgets('text field is autofocused when autoFocus is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                  autoFocus: true,
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.autofocus, isTrue);
      });

      testWidgets('text field is not autofocused by default', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(
                _createMockProfileRepository(),
              ),
              followRepositoryProvider.overrideWithValue(
                _createMockFollowRepository(),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.allUsers,
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.autofocus, isFalse);
      });
    });

    group('excludePubkeys', () {
      testWidgets('shows excluded users as disabled with check icon', (
        tester,
      ) async {
        final followPubkeys = ['pubkey1', 'pubkey2'];
        final profiles = [
          UserProfile(
            pubkey: 'pubkey1',
            name: 'Already Selected',
            rawData: const {'name': 'Already Selected'},
            createdAt: DateTime.now(),
            eventId: 'event1',
          ),
          UserProfile(
            pubkey: 'pubkey2',
            name: 'Available User',
            rawData: const {'name': 'Available User'},
            createdAt: DateTime.now(),
            eventId: 'event2',
          ),
        ];

        final mockFollowRepo = _createMockFollowRepository(
          followingPubkeys: followPubkeys,
        );

        final mockProfileRepo = _createMockProfileRepository();
        when(
          () => mockProfileRepo.getCachedProfile(pubkey: 'pubkey1'),
        ).thenAnswer((_) async => profiles[0]);
        when(
          () => mockProfileRepo.getCachedProfile(pubkey: 'pubkey2'),
        ).thenAnswer((_) async => profiles[1]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileRepositoryProvider.overrideWithValue(mockProfileRepo),
              followRepositoryProvider.overrideWithValue(mockFollowRepo),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: UserPickerSheet(
                  filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  excludePubkeys: {'pubkey1'},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both users should be visible
        expect(find.text('Already Selected'), findsOneWidget);
        expect(find.text('Available User'), findsOneWidget);

        // SVG icons shown for each user (Check.svg for excluded, plus.svg for
        // available)
        expect(find.byType(SvgPicture), findsNWidgets(2));
      });
    });

    group('null profileRepository', () {
      testWidgets(
        'shows error state for allUsers mode when profileRepository is null',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(null),
                followRepositoryProvider.overrideWithValue(
                  _createMockFollowRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.allUsers,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text(
              'User search is unavailable. Please try again later.',
            ),
            findsOneWidget,
          );
          // Should not show the search field
          expect(find.byType(TextField), findsNothing);
        },
      );

      testWidgets(
        'shows error state for mutualFollowsOnly mode '
        'when profileRepository is null',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                profileRepositoryProvider.overrideWithValue(null),
                followRepositoryProvider.overrideWithValue(
                  _createMockFollowRepository(),
                ),
              ],
              child: const MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: UserPickerSheet(
                    filterMode: UserPickerFilterMode.mutualFollowsOnly,
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(
            find.text(
              'User search is unavailable. Please try again later.',
            ),
            findsOneWidget,
          );
          // Should not show the search field
          expect(find.byType(TextField), findsNothing);
        },
      );
    });
  });

  group(UserPickerFilterMode, () {
    test('has correct enum values', () {
      expect(UserPickerFilterMode.values.length, equals(2));
      expect(
        UserPickerFilterMode.values,
        contains(UserPickerFilterMode.mutualFollowsOnly),
      );
      expect(
        UserPickerFilterMode.values,
        contains(UserPickerFilterMode.allUsers),
      );
    });
  });
}
