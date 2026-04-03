import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/search_results/cubit/search_results_filter_cubit.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';

void main() {
  group(SearchResultsFilterCubit, () {
    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'initial state is ${SearchResultsFilter.all}',
      build: SearchResultsFilterCubit.new,
      verify: (cubit) => expect(cubit.state, equals(SearchResultsFilter.all)),
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [people] when setFilter is called with people',
      build: SearchResultsFilterCubit.new,
      act: (cubit) => cubit.setFilter(SearchResultsFilter.people),
      expect: () => const [SearchResultsFilter.people],
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [all] when resetFilter is called',
      build: SearchResultsFilterCubit.new,
      seed: () => SearchResultsFilter.people,
      act: (cubit) => cubit.resetFilter(),
      expect: () => const [SearchResultsFilter.all],
    );

    blocTest<SearchResultsFilterCubit, SearchResultsFilter>(
      'emits [people, all] for a full round-trip',
      build: SearchResultsFilterCubit.new,
      act: (cubit) {
        cubit.setFilter(SearchResultsFilter.people);
        cubit.resetFilter();
      },
      expect: () => const [
        SearchResultsFilter.people,
        SearchResultsFilter.all,
      ],
    );
  });
}
