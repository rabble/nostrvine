// ABOUTME: Comprehensive widget test for UserAvatar covering image loading,
// ABOUTME: fallbacks, and interactions

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../helpers/golden_test_devices.dart';

void main() {
  group('UserAvatar - Comprehensive Tests', () {
    group('Basic Widget Structure', () {
      testWidgets('creates correct widget structure with default values', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: UserAvatar())),
        );

        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(GestureDetector), findsOneWidget);
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(find.byType(SizedBox), findsWidgets);

        // Verify default size of 44
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, 44);
        expect(sizedBox.height, 44);

        // Verify ClipRRect border radius
        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, BorderRadius.circular(44 * 0.286));
      });

      testWidgets('applies custom size correctly', (tester) async {
        const customSize = 80.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(size: customSize)),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, customSize);
        expect(sizedBox.height, customSize);

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(
          clipRRect.borderRadius,
          BorderRadius.circular(customSize * 0.286),
        );
      });
    });

    group('Image Loading States', () {
      testWidgets('shows CachedNetworkImage when imageUrl is provided', (
        tester,
      ) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(imageUrl: testImageUrl)),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.imageUrl, testImageUrl);
        expect(cachedImage.fit, BoxFit.cover);
        expect(cachedImage.width, 44); // default size
        expect(cachedImage.height, 44);
      });

      testWidgets('shows fallback when imageUrl is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: 'Test User')),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        // Should show fallback avatar image
        expect(find.byType(Image), findsAtLeastNWidgets(1));
      });

      testWidgets('shows fallback when imageUrl is empty', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(imageUrl: '', name: 'Test User'),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('shows default asset image fallback when name is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: 'John Doe')),
          ),
        );

        // Should show fallback asset image, not initials
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('shows default asset image when no name is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: UserAvatar())),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('shows same fallback regardless of name value', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: 'Madonna')),
          ),
        );

        // Fallback is always the asset image, name is only for semantics
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('shows fallback for empty name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: '')),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('shows fallback for long names', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                name: 'Very Long First Name And Very Long Last Name',
              ),
            ),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
      });
    });

    group('Image Error Handling', () {
      testWidgets('shows error widget when image fails to load', (
        tester,
      ) async {
        const failingImageUrl = 'https://example.com/nonexistent.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(imageUrl: failingImageUrl, name: 'Test User'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.errorWidget, isNotNull);
      });

      testWidgets('shows placeholder while image is loading', (tester) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(imageUrl: testImageUrl, name: 'Test User'),
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.placeholder, isNotNull);
      });
    });

    group('Tap Interactions', () {
      testWidgets('calls onTap when avatar is tapped', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: UserAvatar(onTap: () => tapped = true)),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('does not respond to taps when onTap is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: UserAvatar())),
        );

        // Should not throw when tapped
        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        // Test passes if no exception is thrown
      });

      testWidgets('onTap works with image avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'https://example.com/avatar.jpg',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('onTap works with fallback avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'Test User', onTap: () => tapped = true),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('Size Variations', () {
      testWidgets('handles very small sizes', (tester) async {
        const smallSize = 16.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: smallSize, name: 'Test'),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, smallSize);
        expect(sizedBox.height, smallSize);
      });

      testWidgets('handles very large sizes', (tester) async {
        const largeSize = 200.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: largeSize, name: 'Test'),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(ClipRRect),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, largeSize);
        expect(sizedBox.height, largeSize);
      });

      testWidgets('CachedNetworkImage respects size parameter', (tester) async {
        const customSize = 60.0;
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: customSize, imageUrl: testImageUrl),
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.width, customSize);
        expect(cachedImage.height, customSize);
      });
    });

    group('Semantics', () {
      testWidgets('provides correct semantics with name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: 'Test User', size: 50)),
          ),
        );

        expect(find.bySemanticsLabel('Test User avatar'), findsOneWidget);
      });

      testWidgets('provides default semantics without name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: UserAvatar(size: 50))),
        );

        expect(find.bySemanticsLabel('User avatar'), findsOneWidget);
      });

      testWidgets('uses custom semantic label when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                name: 'Test User',
                semanticLabel: 'Custom label',
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Custom label'), findsOneWidget);
      });
    });

    group('Edge Cases and Robustness', () {
      testWidgets('handles zero size gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: UserAvatar(size: 0))),
        );

        // Should not crash
        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('handles names with special characters', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: 'José María')),
          ),
        );

        // Widget should render without crashing
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('handles names with numbers', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: 'User123 Test456')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('handles whitespace-only names', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: UserAvatar(name: '   ')),
          ),
        );

        // Widget should render with fallback image
        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('handles malformed URLs gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'not-a-valid-url',
                name: 'Fallback User',
              ),
            ),
          ),
        );

        // Should fall back to initials without crashing
        await tester.pumpAndSettle();
        expect(find.byType(UserAvatar), findsOneWidget);
      });
    });

    group('Multiple Avatars', () {
      testWidgets('renders multiple avatars correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  UserAvatar(name: 'User One', size: 40),
                  UserAvatar(name: 'User Two', size: 50),
                  UserAvatar(
                    imageUrl: 'https://example.com/avatar.jpg',
                    size: 60,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(UserAvatar), findsNWidgets(3));
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });
    });

    // Golden Tests Section - kept skipped as they require golden file generation
    group(
      'Golden Tests',
      skip:
          'Golden tests require golden file generation '
          'and are maintained separately',
      () {
        testGoldens('UserAvatar - different states visual test', (
          tester,
        ) async {
          final builder = GoldenBuilder.grid(columns: 3, widthToHeightRatio: 1)
            ..addScenario(
              'With Name',
              const UserAvatar(name: 'John Doe', size: 60),
            )
            ..addScenario('Empty Name', const UserAvatar(name: '', size: 60))
            ..addScenario('No Name', const UserAvatar(size: 60))
            ..addScenario(
              'Single Letter',
              const UserAvatar(name: 'A', size: 60),
            )
            ..addScenario(
              'Special Chars',
              const UserAvatar(name: '@user!', size: 60),
            )
            ..addScenario(
              'Long Name',
              const UserAvatar(name: 'Alexander Hamilton', size: 60),
            );

          await tester.pumpWidgetBuilder(
            builder.build(),
            wrapper: materialAppWrapper(),
          );
          await screenMatchesGolden(tester, 'user_avatar_states_integrated');
        });

        testGoldens('UserAvatar - size variations visual test', (tester) async {
          final builder = GoldenBuilder.grid(columns: 4, widthToHeightRatio: 1)
            ..addScenario('XS (16px)', const UserAvatar(name: 'User', size: 16))
            ..addScenario('S (24px)', const UserAvatar(name: 'User', size: 24))
            ..addScenario('M (40px)', const UserAvatar(name: 'User', size: 40))
            ..addScenario('L (60px)', const UserAvatar(name: 'User', size: 60))
            ..addScenario('XL (80px)', const UserAvatar(name: 'User', size: 80))
            ..addScenario(
              'XXL (100px)',
              const UserAvatar(name: 'User', size: 100),
            );

          await tester.pumpWidgetBuilder(
            builder.build(),
            wrapper: materialAppWrapper(),
          );
          await screenMatchesGolden(tester, 'user_avatar_sizes_integrated');
        });

        testGoldens('UserAvatar - themes visual test', (tester) async {
          await tester.pumpWidgetBuilder(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Theme(
                  data: ThemeData.dark(),
                  child: Container(
                    color: Colors.grey[900],
                    padding: const EdgeInsets.all(20),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(name: 'Dark Theme', size: 60),
                        SizedBox(width: 20),
                        UserAvatar(name: '', size: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            wrapper: materialAppWrapper(),
          );
          await screenMatchesGolden(tester, 'user_avatar_themes_integrated');
        });

        testGoldens('UserAvatar - across devices', (tester) async {
          final widget = Scaffold(
            appBar: AppBar(title: const Text('User Avatars')),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      UserAvatar(name: 'Alice', size: 50),
                      UserAvatar(name: 'Bob', size: 50),
                      UserAvatar(name: 'Charlie', size: 50),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      UserAvatar(name: '', size: 50),
                      UserAvatar(size: 50),
                      UserAvatar(name: 'Z', size: 50),
                    ],
                  ),
                ],
              ),
            ),
          );

          await tester.pumpWidgetBuilder(widget, wrapper: materialAppWrapper());

          await multiScreenGolden(
            tester,
            'user_avatar_devices_integrated',
            devices: GoldenTestDevices.minimalDevices,
          );
        });
      },
    );
  });
}
