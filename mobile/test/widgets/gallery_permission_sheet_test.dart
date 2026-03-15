// ABOUTME: Widget tests for the gallery permission bottom sheet.
// ABOUTME: Verifies Open Settings, Not Now, and Don't Ask Again actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/divine_primary_button.dart';
import 'package:openvine/widgets/divine_secondary_button.dart';
import 'package:openvine/widgets/gallery_permission_sheet.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  late _MockPermissionsService mockPermissionsService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockPermissionsService = _MockPermissionsService();
    when(
      () => mockPermissionsService.openAppSettings(),
    ).thenAnswer((_) async => true);
  });

  Widget buildSubject() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final choice = await showGalleryPermissionSheet(
                context,
                permissionsService: mockPermissionsService,
              );
              if (!context.mounted) return;
              // Surface the result as text so tests can verify it.
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('result:${choice.name}')),
              );
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  group('showGalleryPermissionSheet', () {
    group('renders', () {
      testWidgets('title with destination name', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Gallery Access Needed'), findsOneWidget);
      });

      testWidgets('description text', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('allow Gallery access in Settings'),
          findsOneWidget,
        );
      });

      testWidgets('alert sticker', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.byType(DivineSticker),
          findsOneWidget,
        );
      });

      testWidgets('$DivinePrimaryButton with Open Settings label', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivinePrimaryButton), findsOneWidget);
        expect(find.text('Open Settings'), findsOneWidget);
      });

      testWidgets('$DivineSecondaryButton with Not Now label', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(DivineSecondaryButton), findsOneWidget);
        expect(find.text('Not Now'), findsOneWidget);
      });

      testWidgets("Don't Ask Again text button", (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text("Don't Ask Again"), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets(
        'tapping Open Settings calls openAppSettings and returns '
        '$GalleryPermissionChoice.openedSettings',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Settings'));
          await tester.pumpAndSettle();

          // Sheet dismissed
          expect(find.text('Gallery Access Needed'), findsNothing);

          verify(() => mockPermissionsService.openAppSettings()).called(1);
          expect(find.text('result:openedSettings'), findsOneWidget);
        },
      );

      testWidgets(
        'tapping Not Now returns $GalleryPermissionChoice.skipped',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Not Now'));
          await tester.pumpAndSettle();

          // Sheet dismissed
          expect(find.text('Gallery Access Needed'), findsNothing);

          verifyNever(() => mockPermissionsService.openAppSettings());
          expect(find.text('result:skipped'), findsOneWidget);
        },
      );

      testWidgets(
        "tapping Don't Ask Again persists flag and returns "
        '$GalleryPermissionChoice.dismissedForever',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.tap(find.text('Open Sheet'));
          await tester.pumpAndSettle();

          await tester.tap(find.text("Don't Ask Again"));
          await tester.pumpAndSettle();

          // Sheet dismissed
          expect(find.text('Gallery Access Needed'), findsNothing);

          expect(find.text('result:dismissedForever'), findsOneWidget);

          // SharedPreferences flag was set
          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getBool('gallery_permission_dismissed_forever'),
            isTrue,
          );
        },
      );
    });
  });

  group('isGalleryPermissionDismissedForever', () {
    test('returns false when flag is not set', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await isGalleryPermissionDismissedForever(), isFalse);
    });

    test('returns true when flag is set', () async {
      SharedPreferences.setMockInitialValues({
        'gallery_permission_dismissed_forever': true,
      });
      expect(await isGalleryPermissionDismissedForever(), isTrue);
    });

    test('returns false when flag is explicitly false', () async {
      SharedPreferences.setMockInitialValues({
        'gallery_permission_dismissed_forever': false,
      });
      expect(await isGalleryPermissionDismissedForever(), isFalse);
    });
  });
}
