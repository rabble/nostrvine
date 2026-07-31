// ABOUTME: Tests private saved-sound label and hashtag autosaving.
// ABOUTME: Covers debounce, normalization, removal, disposal, and retry state.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/saved_sound_details_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoProbe implements SavedSoundMediaProbe {
  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

class _FailingService extends SavedSoundsService {
  _FailingService(super.preferences);

  @override
  Future<void> replaceSavedSound(SavedSound sound) async {
    throw StateError('write failed');
  }
}

const _audio = AudioEvent(
  id: 'sound-id',
  pubkey: 'creator',
  createdAt: 1,
  title: 'Rain',
);

SavedSound _record({
  String? label = 'Morning loop',
  List<String> hashtags = const ['rain'],
}) => SavedSound(
  audio: _audio,
  personalLabel: label,
  personalHashtags: hashtags,
  catalogTags: const [],
  waveformSamples: const [],
);

Future<(SavedSoundsBloc, SavedSoundsService)> _bloc({
  bool failWrites = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final service = failWrites
      ? _FailingService(preferences)
      : SavedSoundsService(preferences);
  await service.saveSavedSound(_record());
  final bloc = SavedSoundsBloc(service: service, mediaProbe: _NoProbe())
    ..add(const SavedSoundsLoadRequested());
  return (bloc, service);
}

Widget _app(SavedSoundsBloc bloc) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  home: Scaffold(
    body: BlocProvider.value(
      value: bloc,
      child: SavedSoundDetailsEditor(sound: _record()),
    ),
  ),
);

void main() {
  testWidgets('shows initial label and hashtags', (tester) async {
    final (bloc, _) = await _bloc();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await bloc.close();
    });

    await tester.pumpWidget(_app(bloc));

    expect(find.text('Morning loop'), findsOneWidget);
    expect(find.text('#rain'), findsOneWidget);
  });

  testWidgets('autosaves a label once after the debounce', (tester) async {
    final (bloc, service) = await _bloc();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await bloc.close();
    });
    await tester.pumpWidget(_app(bloc));

    await tester.enterText(
      find.byKey(const Key('saved_sound_label_field')),
      'Field recording',
    );
    await tester.pump(const Duration(milliseconds: 349));
    expect(service.loadSavedSounds().single.personalLabel, 'Morning loop');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(service.loadSavedSounds().single.personalLabel, 'Field recording');
  });

  testWidgets('commits normalized unique hashtags on delimiters', (
    tester,
  ) async {
    final (bloc, service) = await _bloc();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await bloc.close();
    });
    await tester.pumpWidget(_app(bloc));

    final field = find.byKey(const Key('saved_sound_hashtag_field'));
    await tester.enterText(field, '#Rain,');
    await tester.enterText(field, '  ');
    await tester.enterText(field, '#Night ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(service.loadSavedSounds().single.personalHashtags, [
      'rain',
      'night',
    ]);
  });

  testWidgets('removes a hashtag and autosaves', (tester) async {
    final (bloc, service) = await _bloc();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await bloc.close();
    });
    await tester.pumpWidget(_app(bloc));

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('saved_sound_hashtag_rain')),
        matching: find.byType(Icon),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(service.loadSavedSounds().single.personalHashtags, isEmpty);
  });

  testWidgets('disposing cancels a pending autosave', (tester) async {
    final (bloc, service) = await _bloc();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await bloc.close();
    });
    await tester.pumpWidget(_app(bloc));
    await tester.enterText(
      find.byKey(const Key('saved_sound_label_field')),
      'Do not persist',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(service.loadSavedSounds().single.personalLabel, 'Morning loop');
  });

  testWidgets('failed persistence keeps text and offers retry', (tester) async {
    final (bloc, _) = await _bloc(failWrites: true);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await bloc.close();
    });
    await tester.pumpWidget(_app(bloc));
    await tester.enterText(
      find.byKey(const Key('saved_sound_label_field')),
      'Still visible',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Still visible'), findsOneWidget);
    expect(find.byKey(const Key('saved_sound_details_retry')), findsOneWidget);
  });
}
