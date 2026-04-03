import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(NostrSettingsScreen, () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    });

    Widget buildSubject() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: NostrSettingsScreen()),
      );
    }

    testWidgets('shows Experimental Features tile and opens feature flags', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Experimental Features'), findsOneWidget);

      await tester.tap(find.text('Experimental Features'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureFlagScreen), findsOneWidget);
    });
  });
}
