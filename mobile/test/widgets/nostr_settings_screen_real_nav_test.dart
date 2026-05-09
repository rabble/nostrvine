import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart' show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      UserProfile(
        pubkey: 'fallback-pubkey',
        displayName: 'Fallback User',
        rawData: const {'display_name': 'Fallback User'},
        createdAt: DateTime(2024),
        eventId:
            'fallback123456789012345678901234567890123456789012345678901234',
      ),
    );
  });

  testWidgets('NIP-05 tile opens the real settings screen', (tester) async {
    final authService = _MockAuthService();
    final profileRepository = _MockProfileRepository();
    final blossomUploadService = _MockBlossomUploadService();
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    final profile = UserProfile(
      pubkey: pubkey,
      displayName: 'Test User',
      rawData: const {'display_name': 'Test User'},
      createdAt: DateTime(2024),
      eventId:
          'event123456789012345678901234567890123456789012345678901234567890',
    );

    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
    when(() => authService.hasExistingProfile).thenReturn(true);
    when(() => profileRepository.getCachedProfile(pubkey: pubkey)).thenAnswer(
      (_) async => profile,
    );
    when(() => profileRepository.fetchFreshProfile(pubkey: pubkey)).thenAnswer(
      (_) async => profile,
    );
    when(
      () => profileRepository.checkUsernameAvailability(
        username: any(named: 'username'),
        currentUserPubkey: any(named: 'currentUserPubkey'),
      ),
    ).thenAnswer((_) async => const UsernameAvailable());
    when(
      () => profileRepository.claimUsername(
        username: any(named: 'username'),
      ),
    ).thenAnswer((_) async => const UsernameClaimSuccess());
    when(() => profileRepository.cacheProfile(any())).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: NostrSettingsScreen.path,
      routes: [
        GoRoute(
          path: NostrSettingsScreen.path,
          builder: (_, _) => const NostrSettingsScreen(),
        ),
        GoRoute(
          path: Nip05SettingsScreen.path,
          name: Nip05SettingsScreen.routeName,
          builder: (_, _) => const Nip05SettingsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
          isFeatureEnabledProvider(
            FeatureFlag.advancedRelaySettings,
          ).overrideWith((ref) => false),
          profileRepositoryProvider.overrideWith((ref) => profileRepository),
          blossomUploadServiceProvider.overrideWith(
            (ref) => blossomUploadService,
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NIP-05 address'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(Nip05SettingsView), findsOneWidget);
  });
}
