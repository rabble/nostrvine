// ABOUTME: Widget tests for NotificationSettingsScreen — verifies the
// ABOUTME: mark-all-as-read action card's success snackbar, failure
// ABOUTME: snackbar, and disabled-when-repo-null behaviour.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/services/notification_preferences_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockNotificationPreferencesService extends Mock
    implements NotificationPreferencesService {}

void main() {
  group(NotificationSettingsScreen, () {
    late _MockNotificationRepository mockRepo;
    late _MockNotificationPreferencesService mockPrefsService;

    setUp(() {
      mockRepo = _MockNotificationRepository();
      mockPrefsService = _MockNotificationPreferencesService();
      when(
        mockPrefsService.loadPreferences,
      ).thenAnswer((_) async => const NotificationPreferences());
    });

    Widget buildSubject({NotificationRepository? repo}) {
      return testMaterialApp(
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
          notificationPreferencesServiceProvider.overrideWithValue(
            mockPrefsService,
          ),
        ],
        home: const NotificationSettingsScreen(),
      );
    }

    testWidgets(
      'shows success snackbar when markAllAsRead succeeds',
      (tester) async {
        when(mockRepo.markAllAsRead).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject(repo: mockRepo));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );

        await tester.scrollUntilVisible(
          find.text(l10n.notificationSettingsMarkAllAsRead),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(mockRepo.markAllAsRead).called(1);
        expect(
          find.text(l10n.notificationSettingsAllMarkedAsRead),
          findsOneWidget,
        );
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, equals(VineTheme.vineGreen));
      },
    );

    testWidgets(
      'shows failure snackbar when markAllAsRead throws',
      (tester) async {
        when(mockRepo.markAllAsRead).thenThrow(Exception('server fail'));

        await tester.pumpWidget(buildSubject(repo: mockRepo));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );

        await tester.scrollUntilVisible(
          find.text(l10n.notificationSettingsMarkAllAsRead),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text(l10n.notificationSettingsMarkAllAsRead));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(mockRepo.markAllAsRead).called(1);
        expect(
          find.text(l10n.notificationSettingsMarkAllAsReadFailed),
          findsOneWidget,
        );
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.backgroundColor, equals(VineTheme.error));
      },
    );

    testWidgets(
      'disables the action card when notificationRepository is null',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NotificationSettingsScreen)),
        );

        await tester.scrollUntilVisible(
          find.text(l10n.notificationSettingsMarkAllAsRead),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        final cardListTile = tester.widget<ListTile>(
          find
              .ancestor(
                of: find.text(l10n.notificationSettingsMarkAllAsRead),
                matching: find.byType(ListTile),
              )
              .first,
        );
        expect(cardListTile.onTap, isNull);
      },
    );
  });
}
