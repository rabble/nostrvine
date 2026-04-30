// ABOUTME: Tests for VineBottomSheet component
// ABOUTME: Verifies structure and behavior of the bottom sheet

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineBottomSheet', () {
    testWidgets('renders with required props', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              body: Column(children: [Text('Content 1'), Text('Content 2')]),
            ),
          ),
        ),
      );

      // Verify header with title (which includes the drag handle)
      expect(find.byType(VineBottomSheetHeader), findsOneWidget);
      expect(find.text('Test Sheet'), findsOneWidget);

      // Verify content is rendered
      expect(find.text('Content 1'), findsOneWidget);
      expect(find.text('Content 2'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              trailing: trailingWidget,
              body: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('renders with bottom input', (tester) async {
      const inputWidget = TextField(
        key: Key('input'),
        decoration: InputDecoration(hintText: 'Add comment...'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              bottomInput: inputWidget,
              body: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('input')), findsOneWidget);
    });

    testWidgets('content is scrollable when expanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: const Text('Test Sheet'),
              body: ListView(
                children: List.generate(
                  50,
                  (index) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify first item is visible
      expect(find.text('Item 0'), findsOneWidget);

      // Last item should not be visible initially
      expect(find.text('Item 49'), findsNothing);

      // Scroll to bottom
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      // Now last item should be visible
      expect(find.text('Item 49'), findsOneWidget);
    });

    testWidgets('wraps content when expanded is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              expanded: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Item 1'), Text('Item 2')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('renders fixed mode with scrollable false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              title: Text('Fixed Sheet'),
              children: [Text('Fixed Content')],
            ),
          ),
        ),
      );

      expect(find.text('Fixed Sheet'), findsOneWidget);
      expect(find.text('Fixed Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              contentTitle: 'Content Title',
              children: [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.text('Content Title'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle in scrollable mode', (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Scrollable Title',
              scrollController: scrollController,
              children: const [Text('Scrollable Content')],
            ),
          ),
        ),
      );

      expect(find.text('Scrollable Title'), findsOneWidget);
      expect(find.text('Scrollable Content'), findsOneWidget);
    });

    testWidgets('renders bottomInput in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              bottomInput: TextField(key: Key('fixed-input')),
              children: [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('fixed-input')), findsOneWidget);
    });

    testWidgets(
      'hides header and shows only drag handle when showHeader is false',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VineBottomSheet(showHeader: false, body: Text('Content')),
            ),
          ),
        );

        expect(find.byType(VineBottomSheetHeader), findsNothing);
        expect(find.byType(VineBottomSheetDragHandle), findsOneWidget);
        expect(find.text('Content'), findsOneWidget);
      },
    );

    testWidgets('hides header in fixed mode when showHeader is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              showHeader: false,
              children: [Text('Fixed Content')],
            ),
          ),
        ),
      );

      expect(find.byType(VineBottomSheetHeader), findsNothing);
      expect(find.byType(VineBottomSheetDragHandle), findsOneWidget);
      expect(find.text('Fixed Content'), findsOneWidget);
    });

    group('VineBottomSheet.show', () {
      testWidgets('shows modal bottom sheet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Modal Sheet'),
                      children: const [Text('Modal Content')],
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        // Tap to show sheet
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Verify sheet is shown
        expect(find.text('Modal Sheet'), findsOneWidget);
        expect(find.text('Modal Content'), findsOneWidget);
      });

      testWidgets('shows fixed mode sheet with scrollable false', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Modal'),
                      children: const [Text('Fixed Modal Content')],
                    );
                  },
                  child: const Text('Show Fixed Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Fixed Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Fixed Modal'), findsOneWidget);
        expect(find.text('Fixed Modal Content'), findsOneWidget);
      });

      testWidgets('calls onShow callback when showing sheet', (tester) async {
        var onShowCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Callback Sheet'),
                      onShow: () => onShowCalled = true,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(onShowCalled, isTrue);
      });

      testWidgets('shows sheet with body parameter', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      body: const Text('Body Content'),
                    );
                  },
                  child: const Text('Show Body Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Body Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Body Content'), findsOneWidget);
      });

      testWidgets('forwards headerPadding to header in scrollable mode', (
        tester,
      ) async {
        const customPadding = EdgeInsetsDirectional.only(
          start: 12,
          end: 12,
          top: 8,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Padded Sheet'),
                      headerPadding: customPadding,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        final header = tester.widget<VineBottomSheetHeader>(
          find.byType(VineBottomSheetHeader),
        );
        expect(header.padding, customPadding);
      });

      testWidgets('forwards headerPadding to header in fixed mode', (
        tester,
      ) async {
        const customPadding = EdgeInsetsDirectional.only(
          start: 16,
          end: 16,
          top: 4,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Padded Sheet'),
                      headerPadding: customPadding,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        final header = tester.widget<VineBottomSheetHeader>(
          find.byType(VineBottomSheetHeader),
        );
        expect(header.padding, customPadding);
      });
    });

    group('tapOutsideToDismiss', () {
      Future<void> showDraggable(
        WidgetTester tester, {
        required bool tapOutsideToDismiss,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      tapOutsideToDismiss: tapOutsideToDismiss,
                      initialChildSize: 0.5,
                      title: const Text('Draggable Sheet'),
                      children: const [Text('Sheet Body')],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Sheet Body'), findsOneWidget);
      }

      testWidgets(
        'dismisses on tap above the sheet when tapOutsideToDismiss is true',
        (tester) async {
          await showDraggable(tester, tapOutsideToDismiss: true);

          // Tap near the top of the screen, above the sheet.
          await tester.tapAt(const Offset(200, 20));
          await tester.pumpAndSettle();

          expect(find.text('Sheet Body'), findsNothing);
        },
      );

      testWidgets(
        'does not dismiss on tap above the sheet when tapOutsideToDismiss '
        'is false',
        (tester) async {
          await showDraggable(tester, tapOutsideToDismiss: false);

          await tester.tapAt(const Offset(200, 20));
          await tester.pumpAndSettle();

          expect(find.text('Sheet Body'), findsOneWidget);
        },
      );

      testWidgets('does not dismiss on tap on non-interactive sheet body', (
        tester,
      ) async {
        await showDraggable(tester, tapOutsideToDismiss: true);

        // Tap directly on the sheet's body text — a non-interactive area.
        await tester.tap(find.text('Sheet Body'));
        await tester.pumpAndSettle();

        expect(find.text('Sheet Body'), findsOneWidget);
      });

      testWidgets('interactive children inside the sheet still receive taps', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      initialChildSize: 0.5,
                      title: const Text('Interactive Sheet'),
                      children: [
                        ElevatedButton(
                          onPressed: () => tapped = true,
                          child: const Text('Inner Button'),
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Inner Button'));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
        // Sheet should still be visible after tapping an inner button.
        expect(find.text('Inner Button'), findsOneWidget);
      });

      testWidgets('fixed mode still dismisses on barrier tap (unchanged)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Sheet'),
                      children: const [Text('Fixed Body')],
                    );
                  },
                  child: const Text('Open Fixed'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Fixed'));
        await tester.pumpAndSettle();
        expect(find.text('Fixed Body'), findsOneWidget);

        // Tap well above the fixed sheet — hits the modal scrim.
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(find.text('Fixed Body'), findsNothing);
      });
    });

    group('new parameters', () {
      test('snap without scrollable fails an assertion', () {
        expect(
          () => VineBottomSheet.show<void>(
            context: _FakeContext(),
            scrollable: false,
            snap: true,
            children: const [Text('x')],
          ),
          throwsAssertionError,
        );
      });

      test('snapSizes without snap fails an assertion', () {
        expect(
          () => VineBottomSheet.show<void>(
            context: _FakeContext(),
            snapSizes: const [0.5, 0.9],
            children: const [Text('x')],
          ),
          throwsAssertionError,
        );
      });

      testWidgets(
        'contentWrapper is applied around the sheet inside the modal route',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        title: const Text('Wrapped'),
                        children: const [Text('Body')],
                        contentWrapper: (wrapperContext, child) =>
                            _WrapperMarker(child: child),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Wrapper wraps the real sheet content.
          expect(find.byType(_WrapperMarker), findsOneWidget);
          expect(find.text('Body'), findsOneWidget);
        },
      );

      testWidgets(
        'contentWrapper is applied in fixed (non-scrollable) mode too',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      await VineBottomSheet.show<void>(
                        context: context,
                        scrollable: false,
                        title: const Text('Wrapped Fixed'),
                        children: const [Text('Fixed Body')],
                        contentWrapper: (wrapperContext, child) =>
                            _WrapperMarker(child: child),
                      );
                    },
                    child: const Text('Open Fixed'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Fixed'));
          await tester.pumpAndSettle();

          expect(find.byType(_WrapperMarker), findsOneWidget);
          expect(find.text('Fixed Body'), findsOneWidget);
        },
      );
    });
    group('onComplete', () {
      testWidgets(
        'shows close and check buttons in header when onComplete is provided',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: VineBottomSheet(
                  scrollable: false,
                  title: const Text('Create'),
                  onComplete: () async {},
                  body: const Text('Body'),
                ),
              ),
            ),
          );

          // Close (X) button and check button should both be present.
          expect(find.byType(DivineIconButton), findsNWidgets(2));
          // Trailing slot is not used when onComplete overrides it.
          expect(find.byType(VineBottomSheetHeader), findsOneWidget);
        },
      );

      testWidgets(
        'close button dismisses the sheet',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Create'),
                      onComplete: () async {},
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsOneWidget);

          // The first DivineIconButton is the close (X) button.
          await tester.tap(find.byType(DivineIconButton).first);
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'check button invokes onComplete then dismisses the sheet',
        (tester) async {
          var completed = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Create'),
                      onComplete: () async {
                        completed = true;
                      },
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsOneWidget);

          // The last DivineIconButton is the check button.
          await tester.tap(find.byType(DivineIconButton).last);
          await tester.pumpAndSettle();

          expect(completed, isTrue);
          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'check button shows loading indicator while onComplete runs',
        (tester) async {
          // Use a completer so we can pause mid-callback and inspect UI.
          var resumeCallback = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Create'),
                      onComplete: () async {
                        // Spin until test unblocks us.
                        while (!resumeCallback) {
                          await Future<void>.delayed(
                            const Duration(milliseconds: 10),
                          );
                        }
                      },
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Tap the check button — callback starts but doesn't finish yet.
          await tester.tap(find.byType(DivineIconButton).last);
          await tester.pump();

          // Loading indicator should be visible instead of the check button.
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          // Only one DivineIconButton remains (the close button).
          expect(find.byType(DivineIconButton), findsOneWidget);

          // Unblock the callback and let the sheet dismiss.
          resumeCallback = true;
          await tester.pumpAndSettle();

          expect(find.text('Sheet body'), findsNothing);
        },
      );

      testWidgets(
        'check button in scrollable mode invokes onComplete then dismisses',
        (tester) async {
          var completed = false;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Create'),
                      onComplete: () async {
                        completed = true;
                      },
                      body: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Both close (X) and check buttons present in scrollable mode.
          expect(find.byType(DivineIconButton), findsNWidgets(2));

          // Tap check button — last DivineIconButton is the check.
          await tester.tap(find.byType(DivineIconButton).last);
          await tester.pumpAndSettle();

          expect(completed, isTrue);
          expect(find.text('Sheet body'), findsNothing);
        },
      );
    });
  });
}

/// in the widget tree exactly once.
class _WrapperMarker extends StatelessWidget {
  const _WrapperMarker({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Minimal BuildContext stand-in used for constructor-time assertion tests
/// that never reach actual widget inflation.
class _FakeContext extends StatelessElement {
  _FakeContext() : super(const _FakeWidget());
}

class _FakeWidget extends StatelessWidget {
  const _FakeWidget();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
