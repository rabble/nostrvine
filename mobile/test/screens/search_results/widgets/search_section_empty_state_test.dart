import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';

void main() {
  group(SearchSectionEmptyState, () {
    Widget buildSubject({required String query}) {
      return MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [SearchSectionEmptyState(query: query)],
          ),
        ),
      );
    }

    testWidgets('renders search icon', (tester) async {
      await tester.pumpWidget(buildSubject(query: 'flutter'));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.search,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders query in message', (tester) async {
      await tester.pumpWidget(buildSubject(query: 'flutter'));

      expect(find.text('No results found for "flutter"'), findsOneWidget);
    });

    testWidgets('renders suggestion text', (tester) async {
      await tester.pumpWidget(buildSubject(query: 'flutter'));

      expect(find.text('Try a different search term'), findsOneWidget);
    });
  });
}
