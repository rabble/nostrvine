import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiVineAppBar', () {
    Widget buildTestWidget({
      String? title,
      Widget? titleWidget,
      String? subtitle,
      DiVineAppBarTitleMode titleMode = DiVineAppBarTitleMode.simple,
      VoidCallback? onTitleTap,
      Widget? titleSuffix,
      bool showBackButton = false,
      VoidCallback? onBackPressed,
      bool showMenuButton = false,
      VoidCallback? onMenuPressed,
      IconSource? leadingIcon,
      VoidCallback? onLeadingPressed,
      List<DiVineAppBarAction> actions = const [],
      DiVineAppBarBackgroundMode backgroundMode =
          DiVineAppBarBackgroundMode.solid,
      DiVineAppBarGradient? gradient,
      Color? backgroundColor,
      DiVineAppBarStyle? style,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          appBar: DiVineAppBar(
            title: title,
            titleWidget: titleWidget,
            subtitle: subtitle,
            titleMode: titleMode,
            onTitleTap: onTitleTap,
            titleSuffix: titleSuffix,
            showBackButton: showBackButton,
            onBackPressed: onBackPressed,
            showMenuButton: showMenuButton,
            onMenuPressed: onMenuPressed,
            leadingIcon: leadingIcon,
            onLeadingPressed: onLeadingPressed,
            actions: actions,
            backgroundMode: backgroundMode,
            gradient: gradient,
            backgroundColor: backgroundColor,
            style: style,
          ),
          body: const SizedBox(),
        ),
      );
    }

    group('title', () {
      testWidgets('renders simple title', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Settings'));

        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('renders titleWidget instead of title string', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            titleWidget: const Text('Custom Widget'),
          ),
        );

        expect(find.text('Custom Widget'), findsOneWidget);
      });

      testWidgets('renders subtitle when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Title',
            subtitle: 'Subtitle text',
          ),
        );

        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Subtitle text'), findsOneWidget);
      });

      testWidgets('renders titleSuffix after title', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleSuffix: const Text('SUFFIX'),
          ),
        );

        expect(find.text('Test'), findsOneWidget);
        expect(find.text('SUFFIX'), findsOneWidget);
      });
    });

    group('title modes', () {
      testWidgets('simple mode is not tappable', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            onTitleTap: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Test'));
        expect(tapped, isFalse);
      });

      testWidgets('tappable mode calls onTitleTap', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.tappable,
            onTitleTap: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Test'));
        expect(tapped, isTrue);
      });

      testWidgets('dropdown mode shows caret icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.dropdown,
            onTitleTap: () {},
          ),
        );

        expect(find.byType(SvgPicture), findsWidgets);
      });

      testWidgets('dropdown mode is tappable', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.dropdown,
            onTitleTap: () => tapped = true,
          ),
        );

        await tester.tap(find.text('Test'));
        expect(tapped, isTrue);
      });
    });

    group('leading', () {
      testWidgets('shows back button when showBackButton is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
          ),
        );

        expect(find.byType(DiVineAppBarIconButton), findsOneWidget);
      });

      testWidgets('back button calls onBackPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            onBackPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DiVineAppBarIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('shows menu button when showMenuButton is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showMenuButton: true,
            onMenuPressed: () {},
          ),
        );

        expect(find.byType(DiVineAppBarIconButton), findsOneWidget);
      });

      testWidgets('menu button calls onMenuPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showMenuButton: true,
            onMenuPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DiVineAppBarIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('shows custom leading icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            leadingIcon: const MaterialIconSource(Icons.close),
            onLeadingPressed: () {},
          ),
        );

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('custom leading calls onLeadingPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            leadingIcon: const MaterialIconSource(Icons.close),
            onLeadingPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DiVineAppBarIconButton));
        expect(pressed, isTrue);
      });

      testWidgets('no leading when all options are false', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
          ),
        );

        expect(find.byType(DiVineAppBarIconButton), findsNothing);
      });
    });

    group('actions', () {
      testWidgets('renders action buttons', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () {},
              ),
            ],
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('renders multiple action buttons', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () {},
              ),
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.settings),
                onPressed: () {},
              ),
            ],
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('action button calls onPressed', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            actions: [
              DiVineAppBarAction(
                icon: const MaterialIconSource(Icons.search),
                onPressed: () => pressed = true,
              ),
            ],
          ),
        );

        await tester.tap(find.byIcon(Icons.search));
        expect(pressed, isTrue);
      });
    });

    group('background modes', () {
      testWidgets('solid mode uses navGreen by default', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, VineTheme.navGreen);
      });

      testWidgets('solid mode uses custom backgroundColor', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundColor: Colors.purple,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.purple);
      });

      testWidgets('transparent mode uses transparent background', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.transparent,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.transparent);
      });

      testWidgets('gradient mode wraps in Container with gradient', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
            gradient: DiVineAppBarGradient.videoOverlay,
          ),
        );

        // Should have a Container with gradient decoration
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasGradient = containers.any((c) {
          final decoration = c.decoration as BoxDecoration?;
          return decoration?.gradient != null;
        });

        expect(hasGradient, isTrue);
      });

      testWidgets('gradient mode sets AppBar background to transparent', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
            gradient: DiVineAppBarGradient.videoOverlay,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, Colors.transparent);
      });
    });

    group('AppBar properties', () {
      testWidgets('has zero elevation', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.elevation, 0);
      });

      testWidgets('has zero scrolledUnderElevation', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.scrolledUnderElevation, 0);
      });

      testWidgets('has correct toolbarHeight', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.toolbarHeight, 72);
      });

      testWidgets('has correct leadingWidth', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leadingWidth, 80);
      });

      testWidgets('has zero titleSpacing', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.titleSpacing, 0);
      });

      testWidgets('does not center title', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.centerTitle, isFalse);
      });

      testWidgets('does not automatically imply leading', (tester) async {
        await tester.pumpWidget(buildTestWidget(title: 'Test'));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.automaticallyImplyLeading, isFalse);
      });
    });

    group('style', () {
      testWidgets('uses default style when not provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.toolbarHeight, 72);
        expect(appBar.leadingWidth, 80);

        final iconButton = tester.widget<DiVineAppBarIconButton>(
          find.byType(DiVineAppBarIconButton),
        );
        expect(iconButton.size, 48);
        expect(iconButton.iconSize, 32);
        expect(iconButton.borderRadius, 20);
      });

      testWidgets('uses provided style for height and leadingWidth', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            style: const DiVineAppBarStyle(
              height: 64,
              leadingWidth: 72,
            ),
          ),
        );

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.toolbarHeight, 64);
        expect(appBar.leadingWidth, 72);
      });

      testWidgets('uses provided style for icon button properties', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            title: 'Test',
            showBackButton: true,
            style: const DiVineAppBarStyle(
              iconButtonSize: 56,
              iconSize: 40,
              iconButtonBorderRadius: 28,
            ),
          ),
        );

        final iconButton = tester.widget<DiVineAppBarIconButton>(
          find.byType(DiVineAppBarIconButton),
        );
        expect(iconButton.size, 56);
        expect(iconButton.iconSize, 40);
        expect(iconButton.borderRadius, 28);
      });

      testWidgets('preferredSize uses style height', (tester) async {
        const customStyle = DiVineAppBarStyle(height: 64);
        const appBar = DiVineAppBar(
          title: 'Test',
          style: customStyle,
        );

        expect(appBar.preferredSize.height, 64);
      });

      testWidgets('preferredSize uses default height when no style', (
        tester,
      ) async {
        const appBar = DiVineAppBar(title: 'Test');

        expect(appBar.preferredSize.height, 72);
      });
    });

    group('assertions', () {
      test('throws when neither title nor titleWidget is provided', () {
        expect(
          DiVineAppBar.new,
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when both showBackButton and showMenuButton are true', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            showBackButton: true,
            showMenuButton: true,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when showBackButton with custom leadingIcon', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            showBackButton: true,
            leadingIcon: const MaterialIconSource(Icons.close),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when showMenuButton with custom leadingIcon', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            showMenuButton: true,
            leadingIcon: const MaterialIconSource(Icons.close),
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when tappable mode without onTitleTap', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.tappable,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when dropdown mode without onTitleTap', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            titleMode: DiVineAppBarTitleMode.dropdown,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when gradient mode without gradient', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            backgroundMode: DiVineAppBarBackgroundMode.gradient,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when leadingIcon without onLeadingPressed', () {
        expect(
          () => DiVineAppBar(
            title: 'Test',
            leadingIcon: const MaterialIconSource(Icons.close),
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
