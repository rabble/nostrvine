// ABOUTME: Tests for AudioListTile widget
// ABOUTME: Validates rendering, selected state, and tap callback

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';

AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioListTile, () {
    late bool tapped;

    setUp(() {
      tapped = false;
    });

    Widget buildWidget({
      required AudioEvent audio,
      bool isSelected = false,
      bool isPlaying = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioListTile(
            audio: audio,
            isSelected: isSelected,
            isPlaying: isPlaying,
            onTap: () => tapped = true,
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders sound title', (tester) async {
        final audio = _createTestAudioEvent(title: 'My Cool Sound');
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.text('My Cool Sound'), findsOneWidget);
      });

      testWidgets('renders untitled sound l10n string when title is null', (
        tester,
      ) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorAudioUntitledSound), findsOneWidget);
      });

      testWidgets('renders formatted duration', (tester) async {
        final audio = _createTestAudioEvent(duration: 125.0);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('02:05'), findsOneWidget);
      });

      testWidgets('renders 00:01 when duration is null', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('00:01'), findsOneWidget);
      });

      testWidgets('renders source when available', (tester) async {
        final audio = _createTestAudioEvent(
          duration: 60.0,
          source: 'Artist Name',
        );
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('Artist Name'), findsOneWidget);
      });

      testWidgets('renders ListTile', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsOneWidget);
      });
    });

    group('Selected state', () {
      testWidgets('renders no trailing indicator when not selected', (
        tester,
      ) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.trailing, isNull);
      });

      testWidgets('renders trailing indicator when selected', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio, isSelected: true));
        await tester.pump();

        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expect(tile.trailing, isNotNull);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onTap when tile is tapped', (tester) async {
        final audio = _createTestAudioEvent();
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('Duration formatting', () {
      testWidgets('formats single digit seconds correctly', (tester) async {
        final audio = _createTestAudioEvent(duration: 5.0);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('00:05'), findsOneWidget);
      });

      testWidgets('formats minutes correctly', (tester) async {
        final audio = _createTestAudioEvent(duration: 90.0);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('01:30'), findsOneWidget);
      });

      testWidgets('truncates fractional seconds', (tester) async {
        final audio = _createTestAudioEvent(duration: 65.7);
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpAndSettle();

        expect(find.textContaining('01:05'), findsOneWidget);
      });
    });
  });
}
