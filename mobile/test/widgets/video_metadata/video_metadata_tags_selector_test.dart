@Tags(['skip_very_good_optimization'])
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';

void main() {
  group(VideoMetadataTagsSelector, () {
    testWidgets('renders tags label when no tags selected', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataTagsSelector()),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoMetadataTagsLabel), findsWidgets);
    });

    testWidgets('renders selected tags joined as value', (tester) async {
      final state = VideoEditorProviderState(
        tags: {'flutter', 'dart'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataTagsSelector()),
          ),
        ),
      );

      expect(find.text('flutter, dart'), findsOneWidget);
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    if (tags != null) {
      state = state.copyWith(tags: tags);
    }
  }
}
