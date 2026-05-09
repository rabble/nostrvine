import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  group(Nip05SettingsView, () {
    late _MockProfileRepository mockProfileRepository;
    late _MockBlossomUploadService mockBlossomUploadService;
    final l10n = lookupAppLocalizations(const Locale('en'));
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    UserProfile createProfile({String? nip05}) {
      return UserProfile(
        pubkey: testPubkey,
        displayName: 'Test User',
        about: 'Still making weird loops',
        picture: 'https://example.com/avatar.png',
        nip05: nip05,
        rawData: {
          'display_name': 'Test User',
          'nip05': ?nip05,
        },
        createdAt: DateTime(2024),
        eventId:
            'event123456789012345678901234567890123456789012345678901234567890',
      );
    }

    setUpAll(() {
      registerFallbackValue(
        UserProfile(
          pubkey: testPubkey,
          displayName: 'Fallback User',
          rawData: const {'display_name': 'Fallback User'},
          createdAt: DateTime(2024),
          eventId:
              'fallback123456789012345678901234567890123456789012345678901234',
        ),
      );
    });

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      mockBlossomUploadService = _MockBlossomUploadService();
      when(
        () => mockProfileRepository.checkUsernameAvailability(
          username: any(named: 'username'),
          currentUserPubkey: any(named: 'currentUserPubkey'),
        ),
      ).thenAnswer((_) async => const UsernameAvailable());
      when(
        () => mockProfileRepository.claimUsername(
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => const UsernameClaimSuccess());
      when(
        () => mockProfileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject({
      required UserProfile profile,
      bool hasExistingProfile = true,
    }) {
      when(
        () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
      ).thenAnswer((_) async => profile);

      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ProfileEditorBloc(
                profileRepository: mockProfileRepository,
                blossomUploadService: mockBlossomUploadService,
                hasExistingProfile: hasExistingProfile,
                currentUserPubkey: testPubkey,
              ),
            ),
            BlocProvider(
              create: (_) => MyProfileBloc(
                profileRepository: mockProfileRepository,
                pubkey: testPubkey,
              )..add(const MyProfileLoadRequested()),
            ),
          ],
          child: const Nip05SettingsView(),
        ),
      );
    }

    testWidgets('prefills an existing external NIP-05 value', (tester) async {
      const existingNip05 = 'alice@example.com';

      await tester.pumpWidget(
        buildSubject(profile: createProfile(nip05: existingNip05)),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05AddressLabel), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.controller?.text == existingNip05,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a confirm dialog before switching to external NIP-05', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: createProfile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05ConfirmTitle), findsOneWidget);
      expect(find.text(l10n.profileSetupNip05ConfirmBody), findsOneWidget);

      await tester.tap(find.text(l10n.profileSetupNip05ConfirmContinue));
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileSetupNip05AddressLabel), findsOneWidget);
    });

    testWidgets(
      'toggle off switches from external NIP-05 back to divine mode',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(profile: createProfile(nip05: 'alice@example.com')),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupNip05AddressLabel), findsOneWidget);

        await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
        await tester.pumpAndSettle();

        expect(find.text(l10n.profileSetupNip05ConfirmTitle), findsNothing);
        expect(find.text(l10n.profileSetupNip05AddressLabel), findsNothing);
      },
    );

    testWidgets('shows validation error for invalid external NIP-05', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profile: createProfile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.profileSetupUseOwnNip05));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileSetupNip05ConfirmContinue));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, 'not-a-handle');
      await tester.pump();

      expect(
        find.text(l10n.profileSetupExternalNip05InvalidFormat),
        findsOneWidget,
      );
    });

    testWidgets('shows a failure snackbar when saving the new NIP-05 fails', (
      tester,
    ) async {
      final profile = createProfile(nip05: 'alice@example.com');
      when(
        () => mockProfileRepository.saveProfileEvent(
          displayName: any(named: 'displayName'),
          about: any(named: 'about'),
          username: any(named: 'username'),
          nip05: any(named: 'nip05'),
          clearNip05: any(named: 'clearNip05'),
          picture: any(named: 'picture'),
          banner: any(named: 'banner'),
          currentProfile: any(named: 'currentProfile'),
        ),
      ).thenThrow(Exception('publish failed'));

      await tester.pumpWidget(buildSubject(profile: profile));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).last,
        'bob@example.com',
      );
      await tester.pump();

      await tester.tap(find.text(l10n.nostrSettingsNip05SaveAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.nostrSettingsNip05SaveFailed), findsOneWidget);
      verify(
        () => mockProfileRepository.saveProfileEvent(
          displayName: 'Test User',
          about: 'Still making weird loops',
          nip05: 'bob@example.com',
          picture: 'https://example.com/avatar.png',
          currentProfile: profile,
        ),
      ).called(1);
    });

    testWidgets(
      'shows retry UI instead of spinning forever when profile load fails',
      (
        tester,
      ) async {
        when(
          () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).thenThrow(Exception('network failed'));

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ProfileEditorBloc(
                    profileRepository: mockProfileRepository,
                    blossomUploadService: mockBlossomUploadService,
                    hasExistingProfile: true,
                    currentUserPubkey: testPubkey,
                  ),
                ),
                BlocProvider(
                  create: (_) => MyProfileBloc(
                    profileRepository: mockProfileRepository,
                    pubkey: testPubkey,
                  )..add(const MyProfileLoadRequested()),
                ),
              ],
              child: const Nip05SettingsView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.profilePleaseTryAgain), findsOneWidget);
        expect(find.text(l10n.profileRetryButton), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text(l10n.profileRetryButton));
        await tester.pumpAndSettle();

        verify(
          () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
        ).called(2);
      },
    );
  });
}
