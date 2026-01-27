import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/gallery/scopes/gallery_callbacks.dart';

void main() {
  group('GalleryCallbacks', () {
    test('stores all callback references', () {
      var startReorderingCalled = false;
      var reorderCancelCalled = false;
      PointerMoveEvent? lastMoveEvent;
      BoxConstraints? lastConstraints;
      int? lastPage;

      final callbacks = GalleryCallbacks(
        onStartReordering: () => startReorderingCalled = true,
        onReorderCancel: () => reorderCancelCalled = true,
        onReorderEvent: (event, constraints) {
          lastMoveEvent = event;
          lastConstraints = constraints;
        },
        onPageChanged: (page) => lastPage = page,
      );

      callbacks.onStartReordering();
      expect(startReorderingCalled, true);

      callbacks.onReorderCancel();
      expect(reorderCancelCalled, true);

      const testEvent = PointerMoveEvent();
      const testConstraints = BoxConstraints(maxWidth: 100);
      callbacks.onReorderEvent(testEvent, testConstraints);
      expect(lastMoveEvent, testEvent);
      expect(lastConstraints, testConstraints);

      callbacks.onPageChanged(5);
      expect(lastPage, 5);
    });
  });

  group('GalleryCallbacksScope', () {
    late GalleryCallbacks testCallbacks;

    setUp(() {
      testCallbacks = GalleryCallbacks(
        onStartReordering: () {},
        onReorderCancel: () {},
        onReorderEvent: (_, _) {},
        onPageChanged: (_) {},
      );
    });

    testWidgets('of() returns callbacks from ancestor', (tester) async {
      GalleryCallbacks? retrievedCallbacks;

      await tester.pumpWidget(
        GalleryCallbacksScope(
          callbacks: testCallbacks,
          child: Builder(
            builder: (context) {
              retrievedCallbacks = GalleryCallbacksScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedCallbacks, testCallbacks);
    });

    testWidgets('read() returns callbacks without rebuild dependency', (
      tester,
    ) async {
      GalleryCallbacks? retrievedCallbacks;

      await tester.pumpWidget(
        GalleryCallbacksScope(
          callbacks: testCallbacks,
          child: Builder(
            builder: (context) {
              retrievedCallbacks = GalleryCallbacksScope.read(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedCallbacks, testCallbacks);
    });

    testWidgets('of() throws assertion when no scope in tree', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            // This should throw an assertion error
            expect(
              () => GalleryCallbacksScope.of(context),
              throwsA(isA<AssertionError>()),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('read() throws assertion when no scope in tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => GalleryCallbacksScope.read(context),
              throwsA(isA<AssertionError>()),
            );
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('updateShouldNotify returns true when callbacks change', (
      tester,
    ) async {
      final callbacks1 = GalleryCallbacks(
        onStartReordering: () {},
        onReorderCancel: () {},
        onReorderEvent: (_, _) {},
        onPageChanged: (_) {},
      );
      final callbacks2 = GalleryCallbacks(
        onStartReordering: () {},
        onReorderCancel: () {},
        onReorderEvent: (_, _) {},
        onPageChanged: (_) {},
      );

      final scope1 = GalleryCallbacksScope(
        callbacks: callbacks1,
        child: const SizedBox(),
      );
      final scope2 = GalleryCallbacksScope(
        callbacks: callbacks2,
        child: const SizedBox(),
      );

      // Different callback instances should trigger update
      expect(scope1.updateShouldNotify(scope2), true);
    });

    testWidgets('updateShouldNotify returns false when same callbacks', (
      tester,
    ) async {
      final scope1 = GalleryCallbacksScope(
        callbacks: testCallbacks,
        child: const SizedBox(),
      );
      final scope2 = GalleryCallbacksScope(
        callbacks: testCallbacks,
        child: const SizedBox(),
      );

      // Same callback instance should not trigger update
      expect(scope1.updateShouldNotify(scope2), false);
    });
  });
}
