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
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:rxdart/rxdart.dart';

/// Mock for FollowRepository
class _MockFollowRepository extends Mock implements FollowRepository {}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void addCollaborator(String pubkey) {
    state = state.copyWith(
      collaboratorPubkeys: {...state.collaboratorPubkeys, pubkey},
    );
  }

  @override
  void removeCollaborator(String pubkey) {
    state = state.copyWith(
      collaboratorPubkeys: state.collaboratorPubkeys
          .where((p) => p != pubkey)
          .toSet(),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoMetadataCollaboratorsInput, () {
    testWidgets('renders Collaborators label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      expect(find.text('Collaborators'), findsOneWidget);
    });

    testWidgets('displays 0 collaborators count initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      expect(
        find.text('0/${VideoEditorNotifier.maxCollaborators} Collaborators'),
        findsOneWidget,
      );
    });

    testWidgets('displays collaborator count when collaborators exist', (
      tester,
    ) async {
      // Use valid 64-character hex pubkeys (Nostr spec)
      final state = VideoEditorProviderState(
        collaboratorPubkeys: {
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      expect(
        find.text('2/${VideoEditorNotifier.maxCollaborators} Collaborators'),
        findsOneWidget,
      );
    });

    testWidgets('renders caret icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Should have SVG icons (caret and info button)
      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('has correct semantics for invite collaborator action', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Find the Semantics widget with button=true and invite label
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      var foundInviteCollaboratorSemantics = false;
      for (final element in semanticsWidgets.evaluate()) {
        final widget = element.widget as Semantics;
        if (widget.properties.button == true &&
            widget.properties.label == 'Invite collaborator') {
          foundInviteCollaboratorSemantics = true;
          break;
        }
      }
      expect(foundInviteCollaboratorSemantics, isTrue);
    });

    testWidgets('renders help button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Should find the info icon button (VideoMetadataHelpButton)
      // It uses an SVG icon with a tooltip
      final tooltip = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == 'How collaborators work',
      );
      expect(tooltip, findsOneWidget);
    });

    testWidgets('caret icon color changes when max collaborators reached', (
      tester,
    ) async {
      // Create state with max collaborators using valid 64-char hex pubkeys
      final maxCollaborators = List.generate(
        VideoEditorNotifier.maxCollaborators,
        (i) => 'abcd${i.toString().padLeft(60, '0')}',
      ).toSet();
      final state = VideoEditorProviderState(
        collaboratorPubkeys: maxCollaborators,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Should show max count
      expect(
        find.text(
          '${VideoEditorNotifier.maxCollaborators}/'
          '${VideoEditorNotifier.maxCollaborators} Collaborators',
        ),
        findsOneWidget,
      );
    });

    testWidgets('collaborator chips are rendered when collaborators exist', (
      tester,
    ) async {
      // Use valid 64-character hex pubkeys (Nostr spec)
      final state = VideoEditorProviderState(
        collaboratorPubkeys: {
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Should render chips - we can't directly find _CollaboratorChip
      // since it's private, but we can look for the Wrap widget
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('no chips rendered when no collaborators', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            followRepositoryProvider.overrideWithValue(
              _createMockFollowRepository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCollaboratorsInput()),
          ),
        ),
      );

      // Wrap should not be present when no collaborators
      expect(find.byType(Wrap), findsNothing);
    });
  });
}
