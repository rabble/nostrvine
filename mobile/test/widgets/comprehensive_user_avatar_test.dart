// ABOUTME: Comprehensive widget test for UserAvatar covering image loading,
// ABOUTME: generated placeholders, geometry, and interactions

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../helpers/golden_test_devices.dart';

const _transparentImageBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB1,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

ClipRRect _clipRRect(WidgetTester tester) =>
    tester.widget<ClipRRect>(find.byType(ClipRRect));

Size _clipSize(WidgetTester tester) => tester.getSize(find.byType(ClipRRect));

Finder _borderFinder() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.border != null;
}, description: 'DecoratedBox with avatar border');

Finder _gradientFinder() => find.byWidgetPredicate((widget) {
  if (widget is! DecoratedBox) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.gradient != null;
}, description: 'DecoratedBox with gradient placeholder');

double _borderWidth(WidgetTester tester) {
  final borderDecoration =
      tester.widget<DecoratedBox>(_borderFinder()).decoration as BoxDecoration;
  final border = borderDecoration.border! as Border;
  return border.top.width;
}

void main() {
  group('UserAvatar - Comprehensive Tests', () {
    group('Basic Widget Structure', () {
      testWidgets('creates default structure without tap wrapper', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar()),
          ),
        );

        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(GestureDetector), findsNothing);
        expect(find.byType(ClipRRect), findsOneWidget);
        expect(_clipSize(tester), const Size.square(44));
        expect(_clipRRect(tester).borderRadius, BorderRadius.circular(17.6));
        expect(_borderFinder(), findsOneWidget);
        expect(_borderWidth(tester), 1);
      });

      testWidgets('wraps avatar in GestureDetector when onTap is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(onTap: () {})),
          ),
        );

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('applies custom size and large-avatar border radius', (
        tester,
      ) async {
        const customSize = 144.0;

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(size: customSize)),
          ),
        );

        expect(_clipSize(tester), const Size.square(customSize));
        expect(_clipRRect(tester).borderRadius, BorderRadius.circular(56));
        expect(_borderWidth(tester), 3);
      });
    });

    group('Image Loading States', () {
      testWidgets('shows CachedNetworkImage when imageUrl is provided', (
        tester,
      ) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(imageUrl: testImageUrl)),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.imageUrl, testImageUrl);
        expect(cachedImage.fit, BoxFit.cover);
        expect(_clipSize(tester), const Size.square(44));
      });

      testWidgets('shows generated placeholder when imageUrl is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'Test User')),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('shows generated placeholder when imageUrl is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(imageUrl: '', name: 'Test User'),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('renders provided imageProvider directly', (tester) async {
        final provider = MemoryImage(
          Uint8List.fromList(_transparentImageBytes),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(imageProvider: provider, name: 'Local User'),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.byType(Image), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, same(provider));
      });

      testWidgets('uses explicit placeholder tone when provided', (
        tester,
      ) async {
        final blueGradientFinder = find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) return false;
          final gradient = decoration.gradient;
          if (gradient is! LinearGradient || gradient.colors.length != 3) {
            return false;
          }
          return gradient.colors[1] == VineTheme.accentBlue;
        }, description: 'blue placeholder background');

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(placeholderTone: UserAvatarPlaceholderTone.blue),
            ),
          ),
        );

        expect(blueGradientFinder, findsOneWidget);
      });
    });

    group('Image Error Handling', () {
      testWidgets('shows error widget when image fails to load', (
        tester,
      ) async {
        const failingImageUrl = 'https://example.com/nonexistent.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar()),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();
      });

      testWidgets('onTap works with image avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      testWidgets('onTap works with placeholder avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
      testWidgets('uses compact corner radius for very small sizes', (
        tester,
      ) async {
        const smallSize = 16.0;

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(size: smallSize, name: 'Test'),
            ),
          ),
        );

        expect(_clipSize(tester), const Size.square(smallSize));
        expect(
          _clipRRect(tester).borderRadius,
          BorderRadius.circular(smallSize / 3),
        );
      });

      testWidgets('caps corner radius for very large sizes', (tester) async {
        const largeSize = 200.0;

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(size: largeSize, name: 'Test'),
            ),
          ),
        );

        expect(_clipSize(tester), const Size.square(largeSize));
        expect(_clipRRect(tester).borderRadius, BorderRadius.circular(56));
      });

      testWidgets('network avatar respects outer size parameter', (
        tester,
      ) async {
        const customSize = 60.0;
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(size: customSize, imageUrl: testImageUrl),
            ),
          ),
        );

        expect(_clipSize(tester), const Size.square(customSize));
      });
    });

    group('Semantics', () {
      testWidgets('provides correct semantics with name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'Test User', size: 50)),
          ),
        );

        expect(find.bySemanticsLabel('Test User avatar'), findsOneWidget);
      });

      testWidgets('provides default semantics without name', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(size: 50)),
          ),
        );

        expect(find.bySemanticsLabel('User avatar'), findsOneWidget);
      });

      testWidgets('uses custom semantic label when provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(size: 0)),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('handles names with special characters', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'José María')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('handles names with numbers', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: 'User123 Test456')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('handles whitespace-only names', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: UserAvatar(name: '   ')),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(_gradientFinder(), findsAtLeastNWidgets(1));
      });

      testWidgets('handles malformed URLs gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'not-a-valid-url',
                name: 'Fallback User',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(UserAvatar), findsOneWidget);
      });
    });

    group('Multiple Avatars', () {
      testWidgets('renders multiple avatars correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
