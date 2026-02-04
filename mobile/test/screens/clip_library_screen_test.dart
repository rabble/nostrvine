// ABOUTME: Tests for ClipLibraryScreen - browsing and managing saved clips
// ABOUTME: Covers thumbnail display, clip deletion, and import functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipLibraryScreen', () {
    late ClipLibraryService clipService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      clipService = ClipLibraryService();
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          clipLibraryServiceProvider.overrideWith((ref) => clipService),
        ],
        child: const MaterialApp(home: ClipLibraryScreen()),
      );
    }

    testWidgets('shows empty state when no clips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No Clips Yet'), findsOneWidget);
      expect(find.text('Record a Video'), findsOneWidget);
    });

    testWidgets('displays clips in grid with thumbnails', (tester) async {
      // Add test clips
      await clipService.saveClip(
        SavedClip(
          id: 'clip_1',
          filePath: '/tmp/video1.mp4',
          thumbnailPath: null, // No thumbnail, will show placeholder
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        ),
      );

      await clipService.saveClip(
        SavedClip(
          id: 'clip_2',
          filePath: '/tmp/video2.mp4',
          thumbnailPath: null,
          duration: const Duration(milliseconds: 1500),
          createdAt: DateTime.now(),
          aspectRatio: 'vertical',
        ),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should show duration badges
      expect(find.text('2.00'), findsOneWidget);
      expect(find.text('1.50'), findsOneWidget);
    });

    group('delete clips functionality', () {
      late SavedClip testClip;

      setUp(() {
        testClip = SavedClip(
          id: 'test_clip',
          filePath: '/tmp/video.mp4',
          thumbnailPath: null,
          duration: const Duration(seconds: 2),
          createdAt: DateTime.now(),
          aspectRatio: 'square',
        );
      });

      testWidgets('shows delete icon when clips selected', (tester) async {
        await clipService.saveClip(testClip);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Find the clip card by its GestureDetector and tap it
        final clipCard = find.byType(GestureDetector).first;
        await tester.tap(clipCard);
        await tester.pump();

        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('shows confirmation dialog on delete tap', (tester) async {
        await clipService.saveClip(testClip);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Select clip
        final clipCard = find.byType(GestureDetector).first;
        await tester.tap(clipCard);
        await tester.pump();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        expect(find.text('Delete Clips'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('deletes clips when confirmed', (tester) async {
        await clipService.saveClip(testClip);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Select clip
        final clipCard = find.byType(GestureDetector).first;
        await tester.tap(clipCard);
        await tester.pump();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Tap confirm button in dialog
        await tester.tap(find.text('Delete'));
        // Use pump with duration to allow async operations to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        final clips = await clipService.getAllClips();
        expect(clips, isEmpty);
      });

      testWidgets('cancels deletion on cancel tap', (tester) async {
        await clipService.saveClip(testClip);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Select clip
        final clipCard = find.byType(GestureDetector).first;
        await tester.tap(clipCard);
        await tester.pump();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        // Tap cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        final clips = await clipService.getAllClips();
        expect(clips.length, 1);
      });

      testWidgets('tapping clip toggles selection', (tester) async {
        await clipService.saveClip(testClip);
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Find the clip card
        final clipCard = find.byType(GestureDetector).first;

        // Select
        await tester.tap(clipCard);
        await tester.pump();
        expect(find.text('1 selected'), findsOneWidget);

        // Deselect by tapping again
        await tester.tap(clipCard);
        await tester.pump();
        expect(find.text('Clips'), findsOneWidget);
      });
    });
  });
}
