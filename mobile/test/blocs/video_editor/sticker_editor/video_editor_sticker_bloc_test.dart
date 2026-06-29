// ABOUTME: Tests for VideoEditorStickerBloc - loading, searching, and filtering stickers.
// ABOUTME: Covers initial state, load events, search functionality, and error handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/repositories/sticker_repository.dart';

class _MockStickerRepository extends Mock implements StickerRepository {}

void main() {
  group('VideoEditorStickerBloc', () {
    late StickerRepository repository;
    late List<StickerData> testStickers;

    setUp(() {
      repository = _MockStickerRepository();
      testStickers = const [
        StickerData.asset(
          'assets/stickers/happy.png',
          description: LocalizedText({
            'en': 'Happy face',
            'de': 'Frohes Gesicht',
          }),
          tags: ['happy', 'smile', 'emoji'],
          packData: StickerPackData.fallback,
        ),
        StickerData.asset(
          'assets/stickers/sad.png',
          description: LocalizedText({'en': 'Sad face'}),
          tags: ['sad', 'cry', 'emoji'],
          packData: StickerPackData.fallback,
        ),
        StickerData.network(
          'https://example.com/star.png',
          description: LocalizedText({'en': 'Golden star'}),
          tags: ['star', 'gold', 'award'],
          packData: StickerPackData.fallback,
        ),
      ];

      when(() => repository.loadStickers(any())).thenAnswer(
        (_) async => testStickers,
      );
    });

    VideoEditorStickerBloc buildBloc() => VideoEditorStickerBloc(
      stickerRepository: repository,
      onPrecacheStickers: (_) {},
    );

    test('initial state is VideoEditorStickerInitial', () async {
      final bloc = buildBloc();
      expect(bloc.state, const VideoEditorStickerInitial());
      await bloc.close();
    });

    group('VideoEditorStickerLoad', () {
      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'emits [loading, loaded] when stickers load successfully',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorStickerLoad('en')),
        expect: () => [
          const VideoEditorStickerLoading(),
          isA<VideoEditorStickerLoaded>()
              .having((s) => s.stickers.length, 'stickers.length', 3)
              .having((s) => s.hasSearchQuery, 'hasSearchQuery', false),
        ],
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'requests stickers for the event locale',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorStickerLoad('de')),
        verify: (_) {
          verify(() => repository.loadStickers('de')).called(1);
        },
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'loads stickers with correct properties',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorStickerLoad('en')),
        verify: (bloc) {
          final state = bloc.state as VideoEditorStickerLoaded;
          expect(state.stickers[0].description, testStickers[0].description);
          expect(state.stickers[0].tags, testStickers[0].tags);
          expect(state.stickers[0].assetPath, testStickers[0].assetPath);
          expect(state.stickers[2].networkUrl, testStickers[2].networkUrl);
        },
      );

      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'wraps unexpected load error in Reportable with context',
        setUp: () {
          when(() => repository.loadStickers(any())).thenThrow(
            const FormatException('corrupt manifest'),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorStickerLoad('en')),
        expect: () => [
          const VideoEditorStickerLoading(),
          const VideoEditorStickerError(),
        ],
        errors: () => [
          isA<Reportable<Object>>()
              .having((r) => r.unwrap(), 'unwrap', isA<FormatException>())
              .having((r) => r.context, 'context', '_onLoad'),
        ],
      );
    });

    group('VideoEditorStickerSearch', () {
      blocTest<VideoEditorStickerBloc, VideoEditorStickerState>(
        'filters stickers by description',
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
        'filters stickers by a non-English localized description',
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('de'))
            ..add(const VideoEditorStickerSearch('frohes'));
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
        'filters stickers by tag',
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
        build: buildBloc,
        act: (bloc) async {
          bloc
            ..add(const VideoEditorStickerLoad('en'))
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
          final state1 = VideoEditorStickerLoaded(
            stickers: testStickers,
            allStickers: testStickers,
          );
          final state2 = VideoEditorStickerLoaded(
            stickers: testStickers,
            allStickers: testStickers,
          );
          final state3 = VideoEditorStickerLoaded(
            stickers: testStickers,
            allStickers: testStickers,
            searchQuery: 'test',
          );

          expect(state1, equals(state2));
          expect(state1, isNot(equals(state3)));
        },
      );

      test('hasSearchQuery returns correct value', () {
        final withQuery = VideoEditorStickerLoaded(
          stickers: testStickers,
          allStickers: testStickers,
          searchQuery: 'test',
        );
        final withoutQuery = VideoEditorStickerLoaded(
          stickers: testStickers,
          allStickers: testStickers,
        );

        expect(withQuery.hasSearchQuery, isTrue);
        expect(withoutQuery.hasSearchQuery, isFalse);
      });

      test('isEmpty returns correct value', () {
        const empty = VideoEditorStickerLoaded(stickers: [], allStickers: []);
        final notEmpty = VideoEditorStickerLoaded(
          stickers: testStickers,
          allStickers: testStickers,
        );

        expect(empty.isEmpty, isTrue);
        expect(notEmpty.isEmpty, isFalse);
      });
    });

    group('VideoEditorStickerEvent', () {
      test('VideoEditorStickerLoad props include localeCode', () {
        const event1 = VideoEditorStickerLoad('en');
        const event2 = VideoEditorStickerLoad('en');
        const event3 = VideoEditorStickerLoad('de');

        expect(event1, equals(event2));
        expect(event1, isNot(equals(event3)));
        expect(event1.props, ['en']);
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
