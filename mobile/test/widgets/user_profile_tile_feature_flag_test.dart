// ABOUTME: Verifies UserProfileTile gates add-to-list on profileListFeatures.
// ABOUTME: Keeps rollout behavior explicit for follower/following entry points.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('UserProfileTile profileListFeatures gating', () {
    late _TestAuthService authService;

    setUp(() {
      authService = _TestAuthService()
        ..setCurrentUser(
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        );
    });

    testWidgets(
      'hides add-to-list action when profileListFeatures is disabled',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            authService: authService,
            profileListFeaturesEnabled: false,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.playlist_add), findsNothing);
      },
    );

    testWidgets(
      'shows add-to-list action when profileListFeatures is enabled',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            authService: authService,
            profileListFeaturesEnabled: true,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.playlist_add), findsOneWidget);
      },
    );
  });
}

Widget _buildSubject({
  required _TestAuthService authService,
  required bool profileListFeaturesEnabled,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: testProviderScope(
      additionalOverrides: [
        authServiceProvider.overrideWithValue(authService),
        isFeatureEnabledProvider(
          FeatureFlag.profileListFeatures,
        ).overrideWithValue(profileListFeaturesEnabled),
      ],
      child: const Scaffold(
        body: UserProfileTile(
          pubkey:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ),
    ),
  );
}

class _TestAuthService implements AuthService {
  String? _currentUser;

  void setCurrentUser(String pubkey) {
    _currentUser = pubkey;
  }

  @override
  String? get currentPublicKeyHex => _currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
