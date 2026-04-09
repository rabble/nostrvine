import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineSearchBar, () {
    Widget buildTestWidget({
      TextEditingController? controller,
      FocusNode? focusNode,
      String hintText = 'Find something cool...',
      bool isLoading = false,
      bool readOnly = false,
      VoidCallback? onTap,
      Widget? suffixIcon,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivineSearchBar(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            isLoading: isLoading,
            readOnly: readOnly,
            onTap: onTap,
            suffixIcon: suffixIcon,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
      );
    }

    testWidgets('renders with default hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Find something cool...'), findsOneWidget);
    });

    testWidgets('renders with custom hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget(hintText: 'Search videos...'));

      expect(find.text('Search videos...'), findsOneWidget);
    });

    testWidgets('shows search icon when not loading', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner when loading', (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.enterText(find.byType(TextField), 'hello');

      expect(controller.text, equals('hello'));
    });

    testWidgets('respects readOnly', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        buildTestWidget(controller: controller, readOnly: true),
      );

      await tester.enterText(find.byType(TextField), 'hello');

      expect(controller.text, isEmpty);
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (value) => changedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'test');

      expect(changedValue, equals('test'));
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(readOnly: true, onTap: () => tapped = true),
      );

      await tester.tap(find.byType(TextField));

      expect(tapped, isTrue);
    });

    testWidgets('renders suffixIcon when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(suffixIcon: const Icon(Icons.filter_list)),
      );

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('does not force suffixIcon to default minimum constraints', (
      tester,
    ) async {
      const suffixKey = Key('suffix');

      await tester.pumpWidget(
        buildTestWidget(
          suffixIcon: const SizedBox(
            key: suffixKey,
            width: 20,
            height: 12,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(suffixKey)), const Size(20, 12));
    });

    testWidgets('renders no suffix when suffixIcon is null', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.byIcon(Icons.filter_list), findsNothing);
    });
  });
}
