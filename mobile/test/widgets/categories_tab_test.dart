// ABOUTME: Widget tests for the categories discovery surface.
// ABOUTME: Verifies loading/error/empty states and the redesigned pinned-first list.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/categories_tab.dart';

void main() {
  Widget buildSubject({
    required CategoriesState state,
    void Function(VideoCategory)? onCategoryTap,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CategoriesDiscoveryView(
          state: state,
          onCategoryTap: onCategoryTap ?? (_) {},
          onRetry: onRetry ?? () {},
        ),
      ),
    );
  }

  group('CategoriesDiscoveryView', () {
    testWidgets('renders loading indicator when status is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loading,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders retry state when loading categories fails', (
      tester,
    ) async {
      var retries = 0;

      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.error,
          ),
          onRetry: () => retries += 1,
        ),
      );

      expect(find.text('Could not load categories'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('renders empty state when there are no categories', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
          ),
        ),
      );

      expect(find.text('No categories available'), findsOneWidget);
    });

    testWidgets('renders featured categories first in a vertical tile list', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'animals', videoCount: 1500),
              VideoCategory(name: 'fashion', videoCount: 1200),
              VideoCategory(name: 'technology', videoCount: 300),
            ],
          ),
        ),
      );

      expect(find.byType(GridView), findsNothing);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);

      final animalsTopLeft = tester.getTopLeft(find.text('Animals'));
      final styleTopLeft = tester.getTopLeft(find.text('Style'));
      final technologyTopLeft = tester.getTopLeft(find.text('Technology'));

      expect(animalsTopLeft.dy, lessThan(styleTopLeft.dy));
      expect(styleTopLeft.dy, lessThan(technologyTopLeft.dy));
    });

    testWidgets('calls back when a category tile is tapped', (tester) async {
      VideoCategory? tappedCategory;

      await tester.pumpWidget(
        buildSubject(
          state: const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'animals', videoCount: 1500)],
          ),
          onCategoryTap: (category) => tappedCategory = category,
        ),
      );

      await tester.tap(find.text('Animals'));

      expect(
        tappedCategory,
        const VideoCategory(name: 'animals', videoCount: 1500),
      );
    });
  });
}
