// ABOUTME: Widget tests for the category gallery screen.
// ABOUTME: Verifies visible sort controls and category gallery state handling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
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

    testWidgets('shows visible Hot, New, and Classic sort options', (
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

      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Hot'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Classic'), findsOneWidget);

      final hotText = tester.widget<Text>(find.text('Hot'));
      final newText = tester.widget<Text>(find.text('New'));
      final classicText = tester.widget<Text>(find.text('Classic'));
      expect(hotText.style?.decoration, TextDecoration.none);
      expect(newText.style?.decoration, TextDecoration.none);
      expect(classicText.style?.decoration, TextDecoration.none);
    });

    testWidgets('calls back when a different sort option is tapped', (
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

      await tester.tap(find.text('Classic'));
      await tester.pump();

      expect(selectedSort, 'classic');
    });

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
