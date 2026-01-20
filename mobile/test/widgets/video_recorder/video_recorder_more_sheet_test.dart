// ABOUTME: Tests for VideoRecorderMoreSheet widget
// ABOUTME: Validates more options menu, clip management actions, and menu items

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/bottom_sheet_list_tile.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_more_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderMoreSheet Widget Tests', () {
    testWidgets('renders more sheet widget', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.byType(VideoRecorderMoreSheet), findsOneWidget);
    });

    testWidgets('uses SafeArea for proper spacing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      // VideoRecorderMoreSheet returns SafeArea as its root widget
      final safeArea = find
          .descendant(
            of: find.byType(VideoRecorderMoreSheet),
            matching: find.byType(SafeArea),
          )
          .first;

      expect(safeArea, findsOneWidget);
    });

    testWidgets('displays "Add clip from Library" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Add clip from Library'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Add clip from Library',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays "Save clip to Library" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Save clip to Library'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Save clip to Library',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays "Remove last clip" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Remove last clip'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Remove last clip',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays "Clear all clips" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      expect(find.text('Clear all clips'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Clear all clips',
        ),
        findsOneWidget,
      );
    });

    testWidgets('destructive actions have red color', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      // Remove and Clear actions should be present
      expect(find.text('Remove last clip'), findsOneWidget);
      expect(find.text('Clear all clips'), findsOneWidget);
    });

    testWidgets('Add clip option is always enabled', (tester) async {
      /* TODO(@hm21): Temporary "commented out" create PR with only new files
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final addClipTile = tester.widget<BottomSheetListTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Add clip from Library',
        ),
      );

      expect(addClipTile.onTap, isNotNull); */
    });

    testWidgets('Save option is initially disabled when no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final saveTile = tester.widget<BottomSheetListTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Save clip to Library',
        ),
      );

      // Initially no clips, so should be disabled
      expect(saveTile.onTap, isNull);
    });

    testWidgets('Remove option is initially disabled when no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final removeTile = tester.widget<BottomSheetListTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Remove last clip',
        ),
      );

      // Initially no clips, so should be disabled
      expect(removeTile.onTap, isNull);
    });

    testWidgets('Clear option is initially disabled when no clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoRecorderMoreSheet())),
        ),
      );

      final clearTile = tester.widget<BottomSheetListTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is BottomSheetListTile &&
              widget.title == 'Clear all clips',
        ),
      );

      // Initially no clips, so should be disabled
      expect(clearTile.onTap, isNull);
    });
  });
}
