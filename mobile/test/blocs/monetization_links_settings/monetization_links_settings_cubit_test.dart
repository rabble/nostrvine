// ABOUTME: Unit tests for MonetizationLinksSettingsCubit validation and save flow.
// ABOUTME: Covers hidden-provider preservation plus typed publish failures.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_cubit.dart';
import 'package:openvine/blocs/monetization_links_settings/monetization_links_settings_state.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(MonetizationLinksSettingsCubit, () {
    const pubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    late _MockProfileRepository repository;
    final trackedLinks = <MonetizationLink>[];
    final savedCallbacks = <UserProfile>[];

    const visibleProviders = [
      MonetizationLinkProvider.cashApp,
      MonetizationLinkProvider.paypal,
      MonetizationLinkProvider.venmo,
    ];

    UserProfile profile({
      String eventId = 'profile-event',
      List<MonetizationLink> links = const [],
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: 'Creator',
        rawData: {
          'display_name': 'Creator',
          if (links.isNotEmpty)
            divineMonetizationLinksKey: [
              for (final link in links) link.toJson(),
            ],
        },
        createdAt: DateTime(2026),
        eventId: eventId,
      );
    }

    MonetizationLinksSettingsCubit buildCubit({
      UserProfile? currentProfile,
    }) {
      return MonetizationLinksSettingsCubit(
        repository: repository,
        profile: currentProfile ?? profile(),
        visibleProviders: visibleProviders,
        trackConfiguredLink: trackedLinks.add,
        onProfileSaved: savedCallbacks.add,
      );
    }

    setUpAll(() {
      registerFallbackValue(
        UserProfile(
          pubkey: pubkey,
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'fallback',
        ),
      );
      registerFallbackValue(<MonetizationLink>[]);
    });

    setUp(() {
      repository = _MockProfileRepository();
      trackedLinks.clear();
      savedCallbacks.clear();
    });

    blocTest<MonetizationLinksSettingsCubit, MonetizationLinksSettingsState>(
      'hydrates provider values and toggles from the current profile',
      build: () => buildCubit(
        currentProfile: profile(
          links: const [
            MonetizationLink(
              provider: MonetizationLinkProvider.cashApp,
              category: MonetizationLinkCategory.tip,
              url: r'https://cash.app/$creator',
              enabled: true,
            ),
          ],
        ),
      ),
      verify: (cubit) {
        expect(
          cubit.state.valueFor(MonetizationLinkProvider.cashApp),
          r'https://cash.app/$creator',
        );
        expect(cubit.state.isEnabled(MonetizationLinkProvider.cashApp), isTrue);
        expect(cubit.state.isEnabled(MonetizationLinkProvider.paypal), isFalse);
      },
    );

    blocTest<MonetizationLinksSettingsCubit, MonetizationLinksSettingsState>(
      'emits typed validation errors without saving',
      build: buildCubit,
      act: (cubit) {
        cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
        cubit.setValue(MonetizationLinkProvider.cashApp, 'https://paypal.me/x');
        return cubit.save();
      },
      expect: () => [
        isA<MonetizationLinksSettingsState>().having(
          (state) => state.isEnabled(MonetizationLinkProvider.cashApp),
          'cash app enabled',
          isTrue,
        ),
        isA<MonetizationLinksSettingsState>().having(
          (state) => state.valueFor(MonetizationLinkProvider.cashApp),
          'cash app value',
          'https://paypal.me/x',
        ),
        isA<MonetizationLinksSettingsState>().having(
          (state) => state.errorFor(MonetizationLinkProvider.cashApp),
          'cash app validation error',
          MonetizationLinkInputInvalidReason.wrongProvider,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.saveProfileEvent(
            displayName: any(named: 'displayName'),
            about: any(named: 'about'),
            website: any(named: 'website'),
            picture: any(named: 'picture'),
            banner: any(named: 'banner'),
            monetizationLinks: any(named: 'monetizationLinks'),
            currentProfile: any(named: 'currentProfile'),
          ),
        );
      },
    );

    blocTest<MonetizationLinksSettingsCubit, MonetizationLinksSettingsState>(
      'keeps save disabled until a real profile is loaded',
      build: () => MonetizationLinksSettingsCubit(
        repository: repository,
        profile: null,
        visibleProviders: visibleProviders,
        trackConfiguredLink: trackedLinks.add,
        onProfileSaved: savedCallbacks.add,
      ),
      verify: (cubit) {
        expect(cubit.state.currentProfile, isNull);
        expect(cubit.state.canSave, isFalse);
      },
    );

    blocTest<MonetizationLinksSettingsCubit, MonetizationLinksSettingsState>(
      'validates an enabled provider with an empty field',
      build: buildCubit,
      act: (cubit) {
        cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
        return cubit.save();
      },
      expect: () => [
        isA<MonetizationLinksSettingsState>().having(
          (state) => state.isEnabled(MonetizationLinkProvider.cashApp),
          'cash app enabled',
          isTrue,
        ),
        isA<MonetizationLinksSettingsState>().having(
          (state) => state.errorFor(MonetizationLinkProvider.cashApp),
          'cash app validation error',
          MonetizationLinkInputInvalidReason.empty,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => repository.saveProfileEvent(
            displayName: any(named: 'displayName'),
            about: any(named: 'about'),
            website: any(named: 'website'),
            picture: any(named: 'picture'),
            banner: any(named: 'banner'),
            monetizationLinks: any(named: 'monetizationLinks'),
            currentProfile: any(named: 'currentProfile'),
          ),
        );
      },
    );

    blocTest<MonetizationLinksSettingsCubit, MonetizationLinksSettingsState>(
      'preserves hidden subscription links when saving visible tip providers',
      setUp: () {
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
          final links =
              (invocation.namedArguments[#monetizationLinks]
                      as Iterable<MonetizationLink>)
                  .toList();
          return profile(eventId: 'saved-profile', links: links);
        });
      },
      build: () => buildCubit(
        currentProfile: profile(
          links: const [
            MonetizationLink(
              provider: MonetizationLinkProvider.patreon,
              category: MonetizationLinkCategory.subscription,
              url: 'https://www.patreon.com/creator',
              enabled: true,
            ),
          ],
        ),
      ),
      act: (cubit) {
        cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
        cubit.setValue(MonetizationLinkProvider.cashApp, r'$creator');
        return cubit.save();
      },
      verify: (cubit) {
        final captured =
            verify(
                  () => repository.saveProfileEvent(
                    displayName: any(named: 'displayName'),
                    about: any(named: 'about'),
                    website: any(named: 'website'),
                    picture: any(named: 'picture'),
                    banner: any(named: 'banner'),
                    monetizationLinks: captureAny(named: 'monetizationLinks'),
                    currentProfile: any(named: 'currentProfile'),
                  ),
                ).captured.single
                as Iterable<MonetizationLink>;
        final byProvider = {
          for (final link in captured) link.provider: link,
        };
        expect(
          byProvider[MonetizationLinkProvider.patreon]?.url,
          'https://www.patreon.com/creator',
        );
        expect(
          byProvider[MonetizationLinkProvider.cashApp]?.url,
          r'https://cash.app/$creator',
        );
        expect(trackedLinks.single.provider, MonetizationLinkProvider.cashApp);
        expect(savedCallbacks.single.eventId, 'saved-profile');
        expect(cubit.state.status, MonetizationLinksSettingsSaveStatus.success);
      },
    );

    blocTest<MonetizationLinksSettingsCubit, MonetizationLinksSettingsState>(
      'maps no-relay publish failures to failure state',
      setUp: () {
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
        ).thenThrow(const NoRelaysConnectedException('no relays'));
      },
      build: buildCubit,
      act: (cubit) {
        cubit.setEnabled(MonetizationLinkProvider.cashApp, true);
        cubit.setValue(MonetizationLinkProvider.cashApp, r'$creator');
        return cubit.save();
      },
      expect: () => [
        isA<MonetizationLinksSettingsState>(),
        isA<MonetizationLinksSettingsState>(),
        isA<MonetizationLinksSettingsState>().having(
          (state) => state.status,
          'status',
          MonetizationLinksSettingsSaveStatus.saving,
        ),
        isA<MonetizationLinksSettingsState>()
            .having(
              (state) => state.status,
              'status',
              MonetizationLinksSettingsSaveStatus.failure,
            )
            .having(
              (state) => state.failure,
              'failure',
              MonetizationLinksSettingsSaveFailure.noRelays,
            ),
      ],
      errors: () => [isA<NoRelaysConnectedException>()],
      verify: (_) {
        expect(trackedLinks, isEmpty);
        expect(savedCallbacks, isEmpty);
      },
    );
  });
}
