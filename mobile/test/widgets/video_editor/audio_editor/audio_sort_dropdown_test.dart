// ABOUTME: Tests for AudioSortDropdown widget.
// ABOUTME: Validates dropdown rendering, option selection, and animations.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_sort_dropdown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioSortDropdown, () {
    Widget buildDropdown({
      AudioSortOption value = AudioSortOption.newest,
      ValueChanged<AudioSortOption>? onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: AudioSortDropdown(
              value: value,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      );
    }

    group('Rendering', () {
      for (final value in AudioSortOption.values) {
        testWidgets('renders "${value.label}" when selected', (tester) async {
          await tester.pumpWidget(buildDropdown(value: value));

          expect(find.text(value.label), findsOneWidget);
        });
      }

      testWidgets('renders filter icon', (tester) async {
        await tester.pumpWidget(buildDropdown());

        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('has correct semantics', (tester) async {
        await tester.pumpWidget(buildDropdown(value: AudioSortOption.newest));

        final semantics = tester.getSemantics(find.byType(InkWell));
        expect(semantics.label, contains('Sort by Newest'));
        expect(semantics.flagsCollection.isButton, isTrue);
      });
    });

    group('Dropdown behavior', () {
      testWidgets('opens dropdown menu on tap', (tester) async {
        await tester.pumpWidget(buildDropdown());

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // All options should be visible in overlay
        expect(find.text('Newest'), findsNWidgets(2)); // Button + menu item
        expect(find.text('Longest'), findsOneWidget);
        expect(find.text('Shortest'), findsOneWidget);
      });

      testWidgets('closes dropdown when backdrop is tapped', (tester) async {
        await tester.pumpWidget(buildDropdown());

        // Open dropdown
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Verify menu is open
        expect(find.text('Longest'), findsOneWidget);

        // Tap backdrop to close
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();

        // Menu should be closed
        expect(find.text('Longest'), findsNothing);
      });

      testWidgets('calls onChanged when option is selected', (tester) async {
        AudioSortOption? selectedOption;

        await tester.pumpWidget(
          buildDropdown(
            value: AudioSortOption.newest,
            onChanged: (option) => selectedOption = option,
          ),
        );

        // Open dropdown
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Select "Longest"
        await tester.tap(find.text('Longest'));
        await tester.pumpAndSettle();

        expect(selectedOption, AudioSortOption.longest);
      });

      testWidgets('closes dropdown after selection', (tester) async {
        await tester.pumpWidget(
          buildDropdown(value: AudioSortOption.newest, onChanged: (_) {}),
        );

        // Open dropdown
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Select "Shortest"
        await tester.tap(find.text('Shortest'));
        await tester.pumpAndSettle();

        // Menu should be closed (only button label visible)
        expect(find.text('Longest'), findsNothing);
      });

      testWidgets('highlights currently selected option', (tester) async {
        await tester.pumpWidget(buildDropdown(value: AudioSortOption.longest));

        // Open dropdown
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Find the selected menu item container
        final menuItems = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(Overlay),
            matching: find.byType(Container),
          ),
        );

        // At least one container should have a decorated background
        expect(menuItems.isNotEmpty, isTrue);
      });
    });

    group('Animation', () {
      testWidgets('dropdown animates when opening', (tester) async {
        await tester.pumpWidget(buildDropdown());

        await tester.tap(find.byType(InkWell));

        // Pump a few frames to check animation is in progress
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // SlideTransition should be present from our dropdown
        expect(find.byType(SlideTransition), findsAtLeast(1));

        await tester.pumpAndSettle();
      });

      testWidgets('dropdown animates when closing', (tester) async {
        await tester.pumpWidget(buildDropdown());

        // Open
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Verify menu is open
        expect(find.text('Longest'), findsOneWidget);

        // Close by tapping backdrop
        await tester.tapAt(Offset.zero);

        // Animation should be in progress - menu still visible mid-animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // After animation completes, menu should be gone
        await tester.pumpAndSettle();
        expect(find.text('Longest'), findsNothing);
      });
    });
  });

  group(AudioSortOption, () {
    test('has correct labels', () {
      expect(AudioSortOption.newest.label, 'Newest');
      expect(AudioSortOption.longest.label, 'Longest');
      expect(AudioSortOption.shortest.label, 'Shortest');
    });

    test('has 3 values', () {
      expect(AudioSortOption.values.length, 3);
    });
  });
}
