// ABOUTME: Tests the app-wide saved sounds BLoC changes with account storage.
// ABOUTME: Ensures an old account BLoC closes before the next bucket is shown.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopProbe implements SavedSoundMediaProbe {
  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

SavedSound _record(String id) => SavedSound.fromLegacy(
  AudioEvent(
    id: id,
    pubkey: 'creator',
    createdAt: 1,
    url: 'https://example.com/$id.m4a',
  ),
);

void main() {
  testWidgets('closes account A bloc and loads only account B records', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final serviceA = SavedSoundsService(preferences, pubkeyHex: 'account-a');
    final serviceB = SavedSoundsService(preferences, pubkeyHex: 'account-b');
    await serviceA.saveSavedSound(_record('sound-a'));
    await serviceB.saveSavedSound(_record('sound-b'));

    SavedSoundsBloc? visibleBloc;

    Widget app(SavedSoundsService service) => MaterialApp(
      home: SavedSoundsScope(
        service: service,
        mediaProbe: _NoopProbe(),
        child: Builder(
          builder: (context) {
            visibleBloc = context.read<SavedSoundsBloc>();
            return BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
              builder: (context, state) => Text(
                state.sounds.map((sound) => sound.id).join(','),
                textDirection: TextDirection.ltr,
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpWidget(app(serviceA));
    await tester.pump();
    final accountABloc = visibleBloc!;
    expect(find.text('sound-a'), findsOneWidget);

    await tester.pumpWidget(app(serviceB));
    await tester.pump();

    expect(accountABloc.isClosed, isTrue);
    expect(visibleBloc, isNot(same(accountABloc)));
    expect(find.text('sound-b'), findsOneWidget);
    expect(find.text('sound-a'), findsNothing);
  });
}
