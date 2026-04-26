import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';

void main() {
  group(VideoMetadataFormFields, () {
    Widget buildWidget({
      VideoEditorProviderState? state,
      bool enableTags = true,
      bool enableExpiration = true,
      bool enableContentWarning = true,
      bool enableCollaborators = true,
      bool enableInspiredBy = true,
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(state ?? VideoEditorProviderState()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: VideoMetadataFormFields(
                enableTags: enableTags,
                enableExpiration: enableExpiration,
                enableContentWarning: enableContentWarning,
                enableCollaborators: enableCollaborators,
                enableInspiredBy: enableInspiredBy,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders $VideoMetadataFormFields', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(VideoMetadataFormFields), findsOneWidget);
    });

    testWidgets('renders Title text field', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineTextField && w.labelText == 'Title',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Description text field', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineTextField && w.labelText == 'Description',
        ),
        findsOneWidget,
      );
    });

    testWidgets('updates title via provider on text change', (tester) async {
      late _MockVideoEditorNotifier mockNotifier;

      mockNotifier = _MockVideoEditorNotifier(VideoEditorProviderState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: VideoMetadataFormFields()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find.byWidgetPredicate(
        (w) => w is DivineTextField && w.labelText == 'Title',
      );
      await tester.enterText(titleField, 'My Video');
      await tester.pumpAndSettle();

      expect(mockNotifier.lastTitle, equals('My Video'));
    });

    testWidgets('updates description via provider on text change', (
      tester,
    ) async {
      late _MockVideoEditorNotifier mockNotifier;

      mockNotifier = _MockVideoEditorNotifier(VideoEditorProviderState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: VideoMetadataFormFields()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descField = find.byWidgetPredicate(
        (w) => w is DivineTextField && w.labelText == 'Description',
      );
      await tester.enterText(descField, 'A description');
      await tester.pumpAndSettle();

      expect(mockNotifier.lastDescription, equals('A description'));
    });

    testWidgets('hides tags section when enableTags is false', (tester) async {
      await tester.pumpWidget(buildWidget(enableTags: false));
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsNothing);
    });

    testWidgets('shows MetadataLimitWarningBanner when present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          state: VideoEditorProviderState(metadataLimitReached: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('64KB limit reached. Remove some content to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('hides MetadataLimitWarningBanner when limit not reached', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('64KB limit reached. Remove some content to continue.'),
        findsNothing,
      );
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  String? lastTitle;
  String? lastDescription;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    if (title != null) lastTitle = title;
    if (description != null) lastDescription = description;
  }
}
