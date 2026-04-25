// ABOUTME: Tests for PauseAwareModals extension, specifically the
// ABOUTME: VineBottomSheet wrapper that video-feed sheets (Metadata,
// ABOUTME: Comments after migration) rely on for tap-outside dismissal
// ABOUTME: and overlay-visibility integration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

void main() {
  group('showVideoPausingVineBottomSheet', () {
    testWidgets(
      'default path dismisses on tap above the sheet (inherits '
      'tapOutsideToDismiss default)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      context.showVideoPausingVineBottomSheet<void>(
                        showHeader: false,
                        initialChildSize: 0.7,
                        buildScrollBody: (scrollController) => ListView(
                          controller: scrollController,
                          children: const [Text('Metadata Body')],
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Metadata Body'), findsOneWidget);

        // Tap above the sheet — simulates the scrim tap.
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(find.text('Metadata Body'), findsNothing);
      },
    );

    testWidgets(
      'sets and clears isBottomSheetOpen on the overlay visibility provider',
      (tester) async {
        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context, listen: false);
                return MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (innerContext) => ElevatedButton(
                        onPressed: () {
                          innerContext.showVideoPausingVineBottomSheet<void>(
                            title: const Text('Title'),
                            children: const [Text('Body')],
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        // Dismiss with outside tap.
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      'tapOutsideToDismiss: false keeps the sheet open on outside tap',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      context.showVideoPausingVineBottomSheet<void>(
                        tapOutsideToDismiss: false,
                        initialChildSize: 0.5,
                        title: const Text('Pinned Sheet'),
                        children: const [Text('Pinned Body')],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Pinned Body'), findsOneWidget);

        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(find.text('Pinned Body'), findsOneWidget);
      },
    );
  });
}
