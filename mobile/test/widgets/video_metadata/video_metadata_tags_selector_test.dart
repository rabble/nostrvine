import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';

void main() {
  late _MockHashtagRepository hashtagRepository;

  setUp(() {
    hashtagRepository = _MockHashtagRepository();
    when(
      () => hashtagRepository.searchHashtags(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const []);
  });

  group(VideoMetadataTagsSelector, () {
    testWidgets('renders tags label when no tags selected', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoMetadataTagsLabel), findsWidgets);
    });

    testWidgets('renders selected tags joined as value', (tester) async {
      final state = VideoEditorProviderState(tags: {'flutter', 'dart'});

      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: state,
        ),
      );

      expect(find.text('flutter, dart'), findsOneWidget);
    });

    testWidgets('pasting multiple tags adds chips and clears the field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(),
        ),
      );

      await tester.tap(
        find.byType(VideoMetadataSelectionTile),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField).last;
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'foo, bar');
      await tester.pump();

      expect(find.text('foo'), findsOneWidget);
      expect(find.text('bar'), findsOneWidget);
      expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
      'tapping a suggestion clears the field but keeps search results visible',
      (tester) async {
        when(
          () => hashtagRepository.searchHashtags(
            query: 'mus',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => ['music']);

        await tester.pumpWidget(
          _buildTestApp(
            hashtagRepository: hashtagRepository,
            videoEditorState: VideoEditorProviderState(),
          ),
        );

        await tester.tap(
          find.byType(VideoMetadataSelectionTile),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchField = find.byType(TextField).last;
        expect(searchField, findsOneWidget);

        await tester.enterText(searchField, 'mus');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('music'), findsOneWidget);

        await tester.tap(find.text('music'));
        await tester.pump();

        // Field is cleared immediately.
        expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);
        // The tapped tag is now a selected chip, and the suggestion chip for
        // 'music' is filtered out by the bloc (it's already selected).
        expect(find.text('music'), findsOneWidget);
        // The previous query results remain visible so the user can rapidly
        // select multiple related tags. 'mus' appears as a suggestion chip
        // (canAddQuery is true for the preserved query).
        expect(find.text('mus'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets('opening with existing tags does not show no-results copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(tags: {'music'}),
        ),
      );

      await tester.tap(
        find.byType(VideoMetadataSelectionTile),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text('music'), findsAtLeastNWidgets(1));
      expect(find.text(l10n.videoMetadataTagsPickerNoResults), findsNothing);
    });

    testWidgets(
      'removing a selected suggestion restores it to the visible results',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        when(
          () => hashtagRepository.searchHashtags(
            query: 'mus',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => ['music', 'musician']);

        await tester.pumpWidget(
          _buildTestApp(
            hashtagRepository: hashtagRepository,
            videoEditorState: VideoEditorProviderState(),
          ),
        );

        await tester.tap(
          find.byType(VideoMetadataSelectionTile),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchField = find.byType(TextField).last;
        await tester.enterText(searchField, 'mus');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.text('music'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('musician'), findsOneWidget);
        expect(find.text('mus'), findsOneWidget);

        await tester.tap(
          find.bySemanticsLabel(l10n.videoMetadataDeleteTagHint('music')),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('music'), findsAtLeastNWidgets(1));
        expect(find.text('musician'), findsOneWidget);
      },
    );
  });
}

Widget _buildTestApp({
  required HashtagRepository hashtagRepository,
  required VideoEditorProviderState videoEditorState,
}) {
  return ProviderScope(
    overrides: [
      hashtagRepositoryProvider.overrideWithValue(hashtagRepository),
      videoEditorProvider.overrideWith(
        () => _MockVideoEditorNotifier(videoEditorState),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: VideoMetadataTagsSelector()),
    ),
  );
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

class _MockHashtagRepository extends Mock implements HashtagRepository {}
