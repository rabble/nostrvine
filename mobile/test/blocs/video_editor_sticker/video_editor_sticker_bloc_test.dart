// ABOUTME: Tests for VideoEditorStickerBloc - loading, searching, and filtering stickers.
// ABOUTME: Covers initial state, load events, search functionality, and error handling.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorStickerBloc', () {
    late List<StickerData> testStickers;

    void mockAssetBundle(List<StickerData> stickers) {
      final jsonList = stickers.map((s) => s.toJson()).toList();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            final jsonString = json.encode(jsonList);
            return ByteData.view(
              Uint8List.fromList(utf8.encode(jsonString)).buffer,
            );
          });
    }

    setUp(() {
      testStickers = const [
        StickerData.asset(
          'assets/stickers/happy.png',
          description: 'Happy face',
          tags: ['happy', 'smile', 'emoji'],
        ),
        StickerData.asset(
          'assets/stickers/sad.png',
          description: 'Sad face',
          tags: ['sad', 'cry', 'emoji'],
        ),
        StickerData.network(
          'https://example.com/star.png',
          description: 'Golden star',
          tags: ['star', 'gold', 'award'],
        ),
      ];

      mockAssetBundle(testStickers);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('initial state is VideoEditorStickerInitial', () async {
      final bloc = VideoEditorStickerBloc(onPrecacheStickers: (_) {});
      expect(bloc.state, const VideoEditorStickerInitial());
      await bloc.close();
    });

    group('VideoEditorStickerLoad', () {
      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'emits [loading, loaded] when stickers load successfully',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) => bloc.add(const VideoEditorStickerLoad()),
        expect: () => [
          const VideoEditorStickerLoading(),
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 3)
              .having((s) => s.hasSearchQuery, 'hasSearchQuery', false),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'loads stickers with correct properties',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) => bloc.add(const VideoEditorStickerLoad()),
        verify: (bloc) {
          final state = bloc.state as VideoEditorStickerLoaded;
          expect(state.stickers[0].description, testStickers[0].description);
          expect(state.stickers[0].tags, testStickers[0].tags);
          expect(state.stickers[0].assetPath, testStickers[0].assetPath);
          expect(state.stickers[2].networkUrl, testStickers[2].networkUrl);
        },
      );
    });

    group('VideoEditorStickerSearch', () {
      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'filters stickers by description',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('happy'));
        },
        skip: 2, // Skip loading and loaded states
        expect: () => [
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 1)
              .having(
                (s) => s.stickers.first.description,
                'first sticker description',
                testStickers[0].description,
              )
              .having((s) => s.searchQuery, 'searchQuery', 'happy')
              .having((s) => s.hasSearchQuery, 'hasSearchQuery', true),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'filters stickers by tag',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('gold'));
        },
        skip: 2,
        expect: () => [
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 1)
              .having(
                (s) => s.stickers.first.description,
                'first sticker description',
                testStickers[2].description,
              ),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'returns all stickers when search query is empty',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('gold'))
            ..add(const VideoEditorStickerSearch(''));
        },
        skip: 3, // Skip loading, loaded, and filtered states
        expect: () => [
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 3)
              .having((s) => s.hasSearchQuery, 'hasSearchQuery', false),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'returns all stickers when search query is whitespace only',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('happy')) // First filter
            ..add(const VideoEditorStickerSearch('   ')); // Then whitespace
        },
        skip: 3, // Skip loading, loaded, and first filter states
        expect: () => [
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 3)
              .having((s) => s.hasSearchQuery, 'hasSearchQuery', false),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'search is case-insensitive',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('HAPPY'));
        },
        skip: 2,
        expect: () => [
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 1)
              .having(
                (s) => s.stickers.first.description,
                'first sticker description',
                testStickers[0].description,
              ),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'returns empty list when no stickers match',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('nonexistent'));
        },
        skip: 2,
        expect: () => [
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers, 'stickers', isEmpty)
              .having((s) => s.isEmpty, 'isEmpty', true)
              .having((s) => s.hasSearchQuery, 'hasSearchQuery', true),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'matches partial tag',
        build: () => VideoEditorStickerBloc(onPrecacheStickers: (_) {}),
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad())
            ..add(const VideoEditorStickerSearch('emo'));
        },
        skip: 2,
        expect: () => [
          isA<VideoEditorStickerLoaded>().having(
            (s) => s.stickers.length,
            'stickers.length',
            2,
          ),
        ],
      );
    });

    group('VideoEditorStickerState', () {
      test(
        'VideoEditorStickerLoaded props include stickers and searchQuery',
        () {
          final state1 = VideoEditorStickerLoaded(stickers: testStickers);
          final state2 = VideoEditorStickerLoaded(stickers: testStickers);
          final state3 = VideoEditorStickerLoaded(
            stickers: testStickers,
            searchQuery: 'test',
          );

          expect(state1, equals(state2));
          expect(state1, isNot(equals(state3)));
        },
      );

      test('VideoEditorStickerError props include message', () {
        const state1 = VideoEditorStickerError('Error 1');
        const state2 = VideoEditorStickerError('Error 1');
        const state3 = VideoEditorStickerError('Error 2');

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });

      test('hasSearchQuery returns correct value', () {
        final withQuery = VideoEditorStickerLoaded(
          stickers: testStickers,
          searchQuery: 'test',
        );
        final withoutQuery = VideoEditorStickerLoaded(stickers: testStickers);

        expect(withQuery.hasSearchQuery, isTrue);
        expect(withoutQuery.hasSearchQuery, isFalse);
      });

      test('isEmpty returns correct value', () {
        const empty = VideoEditorStickerLoaded(stickers: []);
        final notEmpty = VideoEditorStickerLoaded(stickers: testStickers);

        expect(empty.isEmpty, isTrue);
        expect(notEmpty.isEmpty, isFalse);
      });
    });

    group('VideoEditorStickerEvent', () {
      test('VideoEditorStickerLoad props are empty', () {
        const event1 = VideoEditorStickerLoad();
        const event2 = VideoEditorStickerLoad();

        expect(event1, equals(event2));
        expect(event1.props, isEmpty);
      });

      test('VideoEditorStickerSearch props include query', () {
        const event1 = VideoEditorStickerSearch('test');
        const event2 = VideoEditorStickerSearch('test');
        const event3 = VideoEditorStickerSearch('other');

        expect(event1, equals(event2));
        expect(event1, isNot(equals(event3)));
        expect(event1.props, ['test']);
      });
    });
  });
}
