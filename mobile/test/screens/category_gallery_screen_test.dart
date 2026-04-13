// ABOUTME: Widget tests for the category gallery screen.
// ABOUTME: Verifies picker-driven category navigation and gallery state handling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/screens/category_gallery_screen.dart';

void main() {
  Widget buildSubject({
    required VideoCategory category,
    required CategoriesState state,
    void Function(String)? onSortChanged,
    VoidCallback? onBack,
    VoidCallback? onRetry,
    Widget? galleryOverride,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CategoryGalleryView(
          category: category,
          state: state,
          onBack: onBack ?? () {},
          onRetry: onRetry ?? () {},
          onSortChanged: onSortChanged ?? (_) {},
          onVideoTap: (videos, index) {},
          onLoadMore: () async {},
          onRefresh: () async {},
          galleryOverride: galleryOverride,
        ),
      ),
    );
  }

  group('CategoryGalleryView', () {
    const category = VideoCategory(name: 'animals', videoCount: 1500);

    testWidgets(
      'shows category title and picker trigger without inline sort labels',
      (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1000, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildSubject(
            category: category,
            state: const CategoriesState(
              selectedCategory: category,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
          ),
        );

        expect(find.text('Animals'), findsOneWidget);
        expect(find.bySemanticsLabel('Category sort options'), findsOneWidget);
        expect(
          find.byKey(const Key('category-header-back-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('category-header-filter-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('category-header-mascot-slot')),
          findsOneWidget,
        );
        expect(find.text('Hot'), findsNothing);
        expect(find.text('New'), findsNothing);
        expect(find.text('Classic'), findsNothing);
        expect(find.text('For You'), findsNothing);

        final backButtonDecoration = tester.widget<DecoratedBox>(
          find.byKey(const Key('category-header-back-button')),
        );
        final backDecoration = backButtonDecoration.decoration as BoxDecoration;
        expect(backDecoration.color, const Color(0xFF3E0C1F));
        expect(backDecoration.border, isNotNull);

        final filterButtonDecoration = tester.widget<DecoratedBox>(
          find.byKey(const Key('category-header-filter-button')),
        );
        final filterDecoration =
            filterButtonDecoration.decoration as BoxDecoration;
        expect(filterDecoration.color, const Color(0xFF3E0C1F));
        expect(filterDecoration.border, isNotNull);

        expect(
          tester.getSize(find.byKey(const Key('category-header-mascot-slot'))),
          const Size(149, 90),
        );

        final filterLeft = tester
            .getTopLeft(find.byKey(const Key('category-header-filter-button')))
            .dx;
        expect(filterLeft, greaterThan(900));

        final backTop = tester
            .getTopLeft(find.byKey(const Key('category-header-back-button')))
            .dy;
        expect(backTop, greaterThan(24));
      },
    );

    testWidgets(
      'opens picker sheet and calls back when a different mode is tapped',
      (
        tester,
      ) async {
        String? selectedSort;

        await tester.pumpWidget(
          buildSubject(
            category: category,
            state: const CategoriesState(
              selectedCategory: category,
              videosStatus: CategoriesVideosStatus.loaded,
            ),
            onSortChanged: (sort) => selectedSort = sort,
          ),
        );

        await tester.tap(find.bySemanticsLabel('Category sort options'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('category-sort-sheet')), findsOneWidget);
        expect(
          find.byKey(const Key('category-sort-sheet-handle')),
          findsOneWidget,
        );
        expect(find.text('Hot'), findsOneWidget);
        expect(find.text('New'), findsOneWidget);
        expect(find.text('Classic'), findsOneWidget);
        expect(find.text('For You'), findsOneWidget);

        final selectedRow = tester.widget<DecoratedBox>(
          find.byKey(const Key('category-sort-option-trending')),
        );
        final selectedRowDecoration = selectedRow.decoration as BoxDecoration;
        expect(selectedRowDecoration.color, const Color(0xFF032017));

        await tester.tap(find.text('For You'));
        await tester.pumpAndSettle();

        expect(selectedSort, 'forYou');
      },
    );

    testWidgets('shows retry state when category videos fail to load', (
      tester,
    ) async {
      var retries = 0;

      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.error,
          ),
          onRetry: () => retries += 1,
        ),
      );

      expect(find.text('Could not load videos'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('shows empty state when selected category has no videos', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loaded,
          ),
        ),
      );

      expect(find.text('No videos in this category'), findsOneWidget);
    });

    testWidgets('renders the gallery content when videos are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          category: category,
          state: const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loaded,
          ),
          galleryOverride: const SizedBox(key: Key('gallery-body')),
        ),
      );

      expect(find.byKey(const Key('gallery-body')), findsOneWidget);
    });
  });
}
