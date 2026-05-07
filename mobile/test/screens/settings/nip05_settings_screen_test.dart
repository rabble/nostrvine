// ABOUTME: Widget tests for the Nostr Settings -> NIP-05 editor screen.
// ABOUTME: Verifies the screen exposes the actual NIP-05 form controls.

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

import '../../helpers/go_router.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(Nip05SettingsScreen, () {
    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    late _MockProfileRepository profileRepository;

    setUpAll(() {
      registerFallbackValue(makeFallbackProfile(pubkey: pubkey));
    });

    UserProfile makeProfile({String? nip05}) {
      return makeFallbackProfile(pubkey: pubkey, nip05: nip05);
    }

    Widget buildSubject({String? nip05, MockGoRouter? goRouter}) {
      final profile = makeProfile(nip05: nip05);
      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => profileRepository.checkUsernameAvailability(
          username: any(named: 'username'),
          currentUserPubkey: any(named: 'currentUserPubkey'),
        ),
      ).thenAnswer((_) async => const UsernameAvailable());

      final app = MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ProfileEditorBloc(
                profileRepository: profileRepository,
                hasExistingProfile: true,
                currentUserPubkey: pubkey,
              ),
            ),
            BlocProvider(
              create: (_) => MyProfileBloc(
                profileRepository: profileRepository,
                pubkey: pubkey,
              )..add(const MyProfileLoadRequested()),
            ),
          ],
          child: const Nip05SettingsView(pubkey: pubkey),
        ),
      );

      if (goRouter == null) return app;
      return MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    setUp(() {
      profileRepository = _MockProfileRepository();
    });

    testWidgets('shows the divine.video username form by default', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(nip05: '_@existing.divine.video'));
      await tester.pumpAndSettle();

      expect(find.text('Username (Optional)'), findsOneWidget);
      expect(find.text('Your unique identity on Divine'), findsOneWidget);
      expect(find.text('existing'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'newname');
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('newname'), findsOneWidget);
    });

    testWidgets('saves the edited divine.video username', (tester) async {
      final goRouter = MockGoRouter();
      when(
        () => profileRepository.claimUsername(username: 'newname'),
      ).thenAnswer((_) async => const UsernameClaimSuccess());
      when(
        () => profileRepository.saveProfileEvent(
          displayName: 'Test User',
          about: 'Still making weird loops',
          username: 'newname',
          picture: 'https://example.com/avatar.png',
          currentProfile: any(named: 'currentProfile'),
        ),
      ).thenAnswer((_) async => makeProfile(nip05: '_@newname.divine.video'));
      when(
        () => profileRepository.cacheProfile(any()),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildSubject(
          nip05: '_@existing.divine.video',
          goRouter: goRouter,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'newname');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save NIP-05'));
      await tester.tap(find.text('Save NIP-05'));
      await tester.pumpAndSettle();

      verify(
        () => profileRepository.claimUsername(username: 'newname'),
      ).called(1);
      verify(
        () => profileRepository.saveProfileEvent(
          displayName: 'Test User',
          about: 'Still making weird loops',
          username: 'newname',
          picture: 'https://example.com/avatar.png',
          currentProfile: any(named: 'currentProfile'),
        ),
      ).called(1);
    });
  });
}

UserProfile makeFallbackProfile({required String pubkey, String? nip05}) {
  return UserProfile(
    pubkey: pubkey,
    displayName: 'Test User',
    about: 'Still making weird loops',
    picture: 'https://example.com/avatar.png',
    nip05: nip05,
    rawData: const {},
    createdAt: DateTime(2024),
    eventId:
        'event123456789012345678901234567890123456789012345678901234567890',
  );
}
