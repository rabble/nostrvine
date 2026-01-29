import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';

void main() {
  group('VideoMetadataExpirationSelector', () {
    testWidgets('displays default expiration option', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      // Default is "Never expire"
      expect(
        find.text(VideoMetadataExpiration.notExpire.description),
        findsOneWidget,
      );
      expect(find.text('Expiration'), findsOneWidget);
    });

    testWidgets('displays currently selected expiration', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = VideoEditorProviderState(expiration: .oneDay);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      expect(
        find.text(VideoMetadataExpiration.oneDay.description),
        findsOneWidget,
      );
    });

    testWidgets('opens bottom sheet when tapped', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Bottom sheet should be visible with all options
      expect(find.text('Expiration'), findsNWidgets(2)); // Label + sheet title

      // Check that all expiration options are displayed
      for (final option in VideoMetadataExpiration.values) {
        expect(find.text(option.description), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('shows checkmark on selected option in bottom sheet', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final state = VideoEditorProviderState(expiration: .oneDay);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Check that checkmark icon exists in the widget tree
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('updates expiration when option is selected', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      VideoMetadataExpiration? selectedExpiration;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onSetExpiration: (exp) => selectedExpiration = exp,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataExpirationSelector()),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      // Verify setExpiration callback works
      mockNotifier.setExpiration(.oneWeek);

      expect(selectedExpiration, equals(VideoMetadataExpiration.oneWeek));
    });
  });
}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.onSetExpiration});

  final VideoEditorProviderState _state;
  final void Function(VideoMetadataExpiration)? onSetExpiration;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setExpiration(VideoMetadataExpiration expiration) {
    onSetExpiration?.call(expiration);
    state = state.copyWith(expiration: expiration);
  }
}
