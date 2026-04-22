import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:rxdart/rxdart.dart';

/// Mock for FollowRepository
class _MockFollowRepository extends Mock implements FollowRepository {}

/// Mock for ContentBlocklistRepository
class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void setInspiredByPerson(String npub) {
    state = state.copyWith(inspiredByNpub: npub);
  }

  @override
  void clearInspiredBy() {
    state = state.copyWith(
      clearInspiredByNpub: true,
      clearInspiredByVideo: true,
    );
  }
}

/// Create a mock FollowRepository
_MockFollowRepository _createMockFollowRepository({
  List<String> followingPubkeys = const [],
}) {
  final mock = _MockFollowRepository();
  when(() => mock.followingPubkeys).thenReturn(followingPubkeys);
  when(() => mock.followingStream).thenAnswer(
    (_) => BehaviorSubject<List<String>>.seeded(followingPubkeys).stream,
  );
  when(() => mock.isInitialized).thenReturn(true);
  when(() => mock.followingCount).thenReturn(followingPubkeys.length);
  return mock;
}

/// Create a mock ContentBlocklistRepository
_MockContentBlocklistRepository _createMockContentBlocklistRepository({
  bool hasMutedUs = false,
}) {
  final mock = _MockContentBlocklistRepository();
  when(() => mock.hasMutedUs(any())).thenReturn(hasMutedUs);
  when(() => mock.isBlocked(any())).thenReturn(false);
  return mock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataInspiredByInput, () {
    testWidgets('renders "Inspired by" label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      expect(find.text('Inspired by'), findsOneWidget);
    });

    testWidgets('displays "None" when no inspiration is set', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('renders caret icon when no inspiration is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Should have SVG icons (caret and info button)
      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('has correct semantics for set inspired by action', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Find the Semantics widget with button=true and 'Set inspired by' label
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      var foundInspiredBySemantics = false;
      for (final element in semanticsWidgets.evaluate()) {
        final widget = element.widget as Semantics;
        if (widget.properties.button == true &&
            widget.properties.label == 'Set inspired by') {
          foundInspiredBySemantics = true;
          break;
        }
      }
      expect(foundInspiredBySemantics, isTrue);
    });

    testWidgets('renders help button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Should find the info icon button (VideoMetadataHelpButton)
      // It uses an SVG icon with a tooltip
      final tooltip = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip &&
            widget.message == 'How inspiration credits work',
      );
      expect(tooltip, findsOneWidget);
    });

    testWidgets('displays inspired by person chip when inspiredByNpub is set', (
      tester,
    ) async {
      final state = VideoEditorProviderState(
        inspiredByNpub:
            'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // Should NOT display "None" when inspired by is set
      expect(find.text('None'), findsNothing);
    });

    testWidgets('InkWell is not tappable when inspired by is set', (
      tester,
    ) async {
      final state = VideoEditorProviderState(
        inspiredByNpub:
            'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // When hasInspiredBy is true, onTap should be null
      final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inkWell.onTap, isNull);
    });

    testWidgets('InkWell is tappable when no inspired by is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _createMockContentBlocklistRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataInspiredByInput()),
          ),
        ),
      );

      // When hasInspiredBy is false, onTap should be defined
      final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inkWell.onTap, isNotNull);
    });
  });
}
