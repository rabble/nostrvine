import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_pill.dart';

class _MockSearchResultsFilterCubit extends MockCubit<SearchResultsFilter>
    implements SearchResultsFilterCubit {}

void main() {
  group(SearchFilterPill, () {
    late _MockSearchResultsFilterCubit mockCubit;

    setUp(() {
      mockCubit = _MockSearchResultsFilterCubit();
    });

    tearDown(() {
      mockCubit.close();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<SearchResultsFilterCubit>.value(
            value: mockCubit,
            child: const SearchFilterPill(),
          ),
        ),
      );
    }

    testWidgets('renders "All" label when filter is all', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('renders "People" label when filter is people', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.people);
      await tester.pumpWidget(buildSubject());

      expect(find.text('People'), findsOneWidget);
    });

    testWidgets('renders "Tags" label when filter is tags', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.tags);
      await tester.pumpWidget(buildSubject());

      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('renders "Videos" label when filter is videos', (
      tester,
    ) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.videos);
      await tester.pumpWidget(buildSubject());

      expect(find.text('Videos'), findsOneWidget);
    });

    testWidgets('does not render caret down icon', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('opens bottom sheet on tap', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(SearchFilterPill));
      await tester.pumpAndSettle();

      // The VineBottomSheetSelectionMenu shows option labels.
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
    });

    testWidgets('has correct semantics', (tester) async {
      when(() => mockCubit.state).thenReturn(SearchResultsFilter.all);
      await tester.pumpWidget(buildSubject());

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Filter: All' &&
              w.properties.button == true,
        ),
        findsOneWidget,
      );
    });
  });
}
