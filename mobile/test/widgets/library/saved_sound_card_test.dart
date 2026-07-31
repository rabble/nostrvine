// ABOUTME: Tests rich saved-sound cards and their source/private metadata.
// ABOUTME: Ensures music-only fallbacks stay quiet and actions remain distinct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/widgets/library/saved_sound_card.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

SavedSound _richSound() => const SavedSound(
  audio: AudioEvent(
    id: 'sound-id',
    pubkey: 'creator',
    createdAt: 1,
    title: 'Audio fallback title',
    duration: 6,
  ),
  personalLabel: 'Morning inspiration',
  personalHashtags: ['ideas', 'funny'],
  catalogTags: ['field recording', 'birds'],
  waveformSamples: [0.1, 0.8, 0.4],
  sourceContext: SavedSoundSourceContext(
    title: 'A tiny bird visits',
    creatorName: 'Alice',
    description: 'Filmed outside before breakfast.',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    transcript: 'Listen to that little bird.',
  ),
);

Widget _app(
  SavedSound sound, {
  VoidCallback? onPreview,
  VoidCallback? onEdit,
  VoidCallback? onRemove,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: SavedSoundCard(
        sound: sound,
        onPreview: onPreview ?? () {},
        onEdit: onEdit ?? () {},
        onRemove: onRemove ?? () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('shows rich source, private, and catalog context', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_richSound()));

    expect(find.byType(VineCachedImage), findsOneWidget);
    expect(find.text('Morning inspiration'), findsOneWidget);
    expect(find.text('A tiny bird visits'), findsOneWidget);
    expect(find.text('By Alice'), findsOneWidget);
    expect(find.text('Filmed outside before breakfast.'), findsOneWidget);
    expect(find.text('Listen to that little bird.'), findsOneWidget);
    expect(find.byKey(const Key('saved_sound_waveform')), findsOneWidget);
    expect(find.text('#ideas'), findsOneWidget);
    expect(find.text('#funny'), findsOneWidget);
    expect(find.text('field recording'), findsOneWidget);
    expect(find.text('birds'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'music-only sound has a quiet fallback without transcript error',
    (
      tester,
    ) async {
      const sound = SavedSound(
        audio: AudioEvent(
          id: 'music',
          pubkey: 'creator',
          createdAt: 1,
          title: 'Instrumental loop',
        ),
        personalHashtags: [],
        catalogTags: [],
        waveformSamples: [],
      );

      await tester.pumpWidget(_app(sound));

      expect(find.text('Instrumental loop'), findsOneWidget);
      expect(
        find.byKey(const Key('saved_sound_thumbnail_fallback')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('saved_sound_transcript')), findsNothing);
      expect(find.byKey(const Key('saved_sound_waveform')), findsNothing);
      expect(
        find.textContaining('transcript', findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets('falls back to localized generic title shape', (tester) async {
    const sound = SavedSound(
      audio: AudioEvent(id: 'empty', pubkey: 'creator', createdAt: 1),
      personalHashtags: [],
      catalogTags: [],
      waveformSamples: [],
    );

    await tester.pumpWidget(_app(sound));

    expect(find.text('Saved sound'), findsOneWidget);
  });

  testWidgets('semantic label includes display title and duration', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_richSound()));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Morning inspiration, 0:06',
      ),
      findsOneWidget,
    );

    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('preview edit and remove callbacks stay distinct', (
    tester,
  ) async {
    var previews = 0;
    var edits = 0;
    var removes = 0;
    await tester.pumpWidget(
      _app(
        _richSound(),
        onPreview: () => previews++,
        onEdit: () => edits++,
        onRemove: () => removes++,
      ),
    );

    await tester.tap(find.byKey(const Key('saved_sound_preview')));
    await tester.tap(find.byKey(const Key('saved_sound_edit')));
    await tester.tap(find.byKey(const Key('saved_sound_remove')));

    expect((previews, edits, removes), (1, 1, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
