// ABOUTME: Tests for audio sharing preference toggle in settings screen
// ABOUTME: Verifies toggle displays and persists user preference

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/theme/vine_theme.dart';

@GenerateMocks([AuthService, AudioSharingPreferenceService])
import 'settings_screen_audio_sharing_test.mocks.dart';

void main() {
  group('SettingsScreen Audio Sharing Toggle', () {
    late MockAuthService mockAuthService;
    late MockAudioSharingPreferenceService mockAudioSharingService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockAudioSharingService = MockAudioSharingPreferenceService();

      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(false);
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          audioSharingPreferenceServiceProvider.overrideWithValue(
            mockAudioSharingService,
          ),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: const SettingsScreen(),
        ),
      );
    }

    testWidgets('displays audio sharing toggle in Preferences section', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should find the toggle in the Preferences section
      expect(find.text('Make my audio available for reuse'), findsOneWidget);
      expect(
        find.text('When enabled, others can use audio from your videos'),
        findsOneWidget,
      );
    });

    testWidgets('toggle shows correct initial state (OFF)', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the SwitchListTile and verify it's OFF
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data ==
                'Make my audio available for reuse' &&
            widget.value == false,
      );
      expect(switchFinder, findsOneWidget);
    });

    testWidgets('toggle shows correct initial state (ON)', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the SwitchListTile and verify it's ON
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data ==
                'Make my audio available for reuse' &&
            widget.value == true,
      );
      expect(switchFinder, findsOneWidget);
    });

    testWidgets('tapping toggle calls setAudioSharingEnabled', (tester) async {
      when(mockAudioSharingService.isAudioSharingEnabled).thenReturn(false);
      when(
        mockAudioSharingService.setAudioSharingEnabled(any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the switch
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data == 'Make my audio available for reuse',
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify the service was called
      verify(mockAudioSharingService.setAudioSharingEnabled(true)).called(1);
    });

    testWidgets('uses correct VineTheme colors', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the switch and verify it uses vineGreen for active thumb
      final switchFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SwitchListTile &&
            widget.title is Text &&
            (widget.title as Text).data ==
                'Make my audio available for reuse' &&
            widget.activeThumbColor == VineTheme.vineGreen,
      );
      expect(switchFinder, findsOneWidget);
    });
  });
}
