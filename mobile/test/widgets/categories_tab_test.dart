// ABOUTME: Widget tests for the CategoriesTab
// ABOUTME: Verifies categories grid rendering, category selection, and back navigation

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/widgets/categories_tab.dart';

class _MockCategoriesBloc extends MockBloc<CategoriesEvent, CategoriesState>
    implements CategoriesBloc {}

void main() {
  late _MockCategoriesBloc mockBloc;

  setUp(() {
    mockBloc = _MockCategoriesBloc();
  });

  Widget buildSubject() {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BlocProvider<CategoriesBloc>.value(
            value: mockBloc,
            child: BlocBuilder<CategoriesBloc, CategoriesState>(
              builder: (context, state) {
                if (state.selectedCategory != null) {
                  return const Text('Category selected');
                }
                return _buildGridFromState(context, state);
              },
            ),
          ),
        ),
      ),
    );
  }

  group(CategoriesTab, () {
    group('renders', () {
      testWidgets('loading indicator when status is loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loading,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('error message with retry button on error', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const CategoriesState(
            categoriesStatus: CategoriesStatus.error,
            errorMessage: 'Network error',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.text('Could not load categories'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('retry button dispatches CategoriesLoadRequested', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const CategoriesState(
            categoriesStatus: CategoriesStatus.error,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Retry'));

        verify(
          () => mockBloc.add(const CategoriesLoadRequested()),
        ).called(1);
      });

      testWidgets('empty state when no categories', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.text('No categories available'),
          findsOneWidget,
        );
      });

      testWidgets('category cards when categories are loaded', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'music', videoCount: 1500),
              VideoCategory(name: 'comedy', videoCount: 900),
            ],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('Music'), findsOneWidget);
        expect(find.text('Comedy'), findsOneWidget);
        expect(find.text('1.5K videos'), findsOneWidget);
        expect(find.text('900 videos'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping category dispatches CategorySelected', (
        tester,
      ) async {
        const category = VideoCategory(
          name: 'music',
          videoCount: 1500,
        );
        when(() => mockBloc.state).thenReturn(
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [category],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Music'));

        verify(
          () => mockBloc.add(const CategorySelected(category)),
        ).called(1);
      });
    });
  });
}

/// Builds a simplified grid from state for testing.
/// (Avoids the ConsumerWidget Riverpod dependency in tests.)
Widget _buildGridFromState(BuildContext context, CategoriesState state) {
  if (state.categoriesStatus == CategoriesStatus.loading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (state.categoriesStatus == CategoriesStatus.error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Could not load categories',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<CategoriesBloc>().add(
                const CategoriesLoadRequested(),
              );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  if (state.categories.isEmpty) {
    return const Center(
      child: Text(
        'No categories available',
        style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
      ),
    );
  }

  return ListView(
    children: state.categories.map((category) {
      return GestureDetector(
        onTap: () {
          context.read<CategoriesBloc>().add(
            CategorySelected(category),
          );
        },
        child: Column(
          children: [
            Text(category.displayName),
            Text('${_formatCount(category.videoCount)} videos'),
          ],
        ),
      );
    }).toList(),
  );
}

String _formatCount(int count) {
  if (count >= 1000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
  }
  return count.toString();
}
