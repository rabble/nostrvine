import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const pubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

  setUpAll(() {
    registerFallbackValue(
      UserProfile(
        pubkey: pubkey,
        displayName: 'Fallback User',
        rawData: const {'display_name': 'Fallback User'},
        createdAt: DateTime(2024),
        eventId:
            'fallback123456789012345678901234567890123456789012345678901234',
      ),
    );
    registerFallbackValue(<MonetizationLink>[]);
  });

  testWidgets('can save monetization links before a profile is cached', (
    tester,
  ) async {
    final authService = _MockAuthService();
    final repository = _MockProfileRepository();
    final profileStream = StreamController<UserProfile?>();
    final l10n = lookupAppLocalizations(const Locale('en'));

    UserProfile? capturedCurrentProfile;
    List<MonetizationLink>? capturedLinks;

    final savedProfile = UserProfile(
      pubkey: pubkey,
      displayName: '',
      rawData: {
        divineMonetizationLinksKey: [
          const MonetizationLink(
            provider: MonetizationLinkProvider.cashApp,
            category: MonetizationLinkCategory.tip,
            url: r'https://cash.app/$creator',
            enabled: true,
          ).toJson(),
        ],
      },
      createdAt: DateTime(2026),
      eventId:
          'saved123456789012345678901234567890123456789012345678901234567890',
    );

    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
    when(() => authService.hasExistingProfile).thenReturn(false);

    when(
      () => repository.getCachedProfile(pubkey: pubkey),
    ).thenAnswer((_) async => null);
    when(
      () => repository.fetchFreshProfile(pubkey: pubkey),
    ).thenAnswer((_) async => null);
    when(
      () => repository.watchProfile(pubkey: pubkey),
    ).thenAnswer((_) => profileStream.stream);
    when(
      () => repository.saveProfileEvent(
        displayName: any(named: 'displayName'),
        about: any(named: 'about'),
        website: any(named: 'website'),
        picture: any(named: 'picture'),
        banner: any(named: 'banner'),
        monetizationLinks: any(named: 'monetizationLinks'),
        currentProfile: any(named: 'currentProfile'),
      ),
    ).thenAnswer((invocation) async {
      capturedCurrentProfile =
          invocation.namedArguments[#currentProfile] as UserProfile?;
      capturedLinks =
          (invocation.namedArguments[#monetizationLinks]
                  as Iterable<MonetizationLink>)
              .toList();
      return savedProfile;
    });

    addTearDown(profileStream.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          profileRepositoryProvider.overrideWithValue(repository),
          analyticsEventSinkProvider.overrideWithValue(
            const NoOpAnalyticsEventSink(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const MonetizationLinksSettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    profileStream.add(null);
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, r'$creator');
    await tester.ensureVisible(find.text(l10n.monetizationSettingsSave));
    await tester.tap(find.text(l10n.monetizationSettingsSave));
    await tester.pump();
    await tester.pump();

    expect(capturedCurrentProfile?.pubkey, pubkey);
    expect(capturedLinks, hasLength(1));
    expect(capturedLinks!.single.provider, MonetizationLinkProvider.cashApp);
    expect(capturedLinks!.single.url, r'https://cash.app/$creator');
    expect(find.text(l10n.monetizationSettingsSaved), findsOneWidget);
  });
}
