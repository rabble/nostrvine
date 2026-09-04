// ABOUTME: Real-router test for the account-deletion gate after `processing`.
// ABOUTME: Pins that the settings screen is unreachable once deletion commits.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

const _processing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.processing,
);

void main() {
  group('Account deletion gate after the coordinator accepts', () {
    late _MockAuthService authService;
    late _MockProfileRepository profileRepository;
    late _MockDeletionRepository deletionRepository;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      authService = _MockAuthService();
      profileRepository = _MockProfileRepository();
      deletionRepository = _MockDeletionRepository();

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
      when(() => authService.hasExistingProfile).thenReturn(true);
      when(() => authService.signerReadiness).thenReturn(SignerReadiness.ready);
      when(authService.signOut).thenAnswer((_) async {});

      final profile = UserProfile(
        pubkey: _pubkey,
        displayName: 'Test User',
        rawData: const {'display_name': 'Test User'},
        createdAt: DateTime(2024),
        eventId:
            'event123456789012345678901234567890123456789012345678901234567890',
      );
      when(
        () => profileRepository.getCachedProfile(pubkey: _pubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: _pubkey),
      ).thenAnswer((_) async => profile);

      // Before the deletion the signer is alive and there is no attempt.
      when(deletionRepository.fetchCurrent).thenAnswer((_) async => null);
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
          isFeatureEnabledProvider(
            FeatureFlag.advancedRelaySettings,
          ).overrideWith((ref) => false),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            deletionRepository,
          ),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
          blossomUploadServiceProvider.overrideWithValue(
            _MockBlossomUploadService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets(
      'a processing answer moves the user off Nostr settings onto the '
      'recovery screen and keeps settings unreachable',
      (tester) async {
        final container = buildContainer();
        await container.read(currentMinorAccountReviewStatusProvider.future);
        await container.read(currentAccountDeletionAttemptProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final router = container.read(goRouterProvider);
        router.go(NostrSettingsScreen.path);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(NostrSettingsScreen), findsOneWidget);

        // From here every lookup fails the way it does in production once
        // the coordinator has deleted the Keycast user: the NIP-98 token
        // cannot be signed. Nothing below may depend on this call succeeding.
        when(deletionRepository.fetchCurrent).thenThrow(
          const AccountDeletionRecoveryException(
            'Could not authorize deletion attempt request',
          ),
        );
        // What `startAccountDeletionFlow` does when `submit` answers
        // `processing`: record the attempt the coordinator handed back, then
        // invalidate the lookup. Awaiting the value here under real time is
        // what proves the record fed it: the lookup above throws, and a
        // provider that reached it would retry for seconds and then fail.
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: _pubkey,
              attempt: _processing,
              vanishEventId:
                  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            );
        container.invalidate(currentAccountDeletionAttemptProvider);
        await tester.runAsync(
          () => container.read(currentAccountDeletionAttemptProvider.future),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          container.read(currentAccountDeletionAttemptProvider).value,
          same(_processing),
        );

        expect(
          router.routeInformationProvider.value.uri.toString(),
          AccountDeletionRecoveryScreen.path,
        );
        expect(find.byType(AccountDeletionRecoveryScreen), findsOneWidget);
        expect(find.byType(NostrSettingsScreen), findsNothing);

        router.go(NostrSettingsScreen.path);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          router.routeInformationProvider.value.uri.toString(),
          AccountDeletionRecoveryScreen.path,
        );
        expect(find.byType(NostrSettingsScreen), findsNothing);
        expect(find.byType(AccountDeletionRecoveryScreen), findsOneWidget);

        // Signing out must not expose Welcome: trying to go back and sign in
        // again remains gated until the deletion result is known.
        router.go('/welcome');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(
          router.routeInformationProvider.value.uri.toString(),
          AccountDeletionRecoveryScreen.path,
        );
        expect(find.byType(AccountDeletionRecoveryScreen), findsOneWidget);

        // Unmount before the fake clock is checked so the recovery poll timer
        // is cancelled with its cubit.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
