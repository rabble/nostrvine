// ABOUTME: Tests for StickerPickerBloc - loading sticker packs and filtering
// ABOUTME: Tests load success/failure and search filtering by shortcode

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sticker_picker/sticker_picker_bloc.dart';
import 'package:sticker_pack_repository/sticker_pack_repository.dart';

class _MockStickerPackRepository extends Mock
    implements StickerPackRepository {}

void main() {
  group(StickerPickerBloc, () {
    late _MockStickerPackRepository mockStickerPackRepository;

    const testPack1 = StickerPack(
      id: 'reactions',
      title: 'Reactions',
      stickers: [
        Sticker(
          shortcode: 'fire',
          imageUrl: 'https://blossom.example.com/fire.webp',
        ),
        Sticker(
          shortcode: 'thumbs-up',
          imageUrl: 'https://blossom.example.com/thumbs-up.webp',
        ),
      ],
      authorPubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    const testPack2 = StickerPack(
      id: 'animals',
      title: 'Animals',
      stickers: [
        Sticker(
          shortcode: 'cat',
          imageUrl: 'https://blossom.example.com/cat.webp',
        ),
      ],
      authorPubkey:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );

    setUp(() {
      mockStickerPackRepository = _MockStickerPackRepository();
    });

    StickerPickerBloc buildBloc() => StickerPickerBloc(
      stickerPackRepository: mockStickerPackRepository,
    );

    test('initial state is $StickerPickerInitial', () {
      final bloc = buildBloc();
      expect(bloc.state, isA<StickerPickerInitial>());
      bloc.close();
    });

    group('StickerPacksLoadRequested', () {
      blocTest<StickerPickerBloc, StickerPickerState>(
        'emits [loading, loaded] on success',
        setUp: () {
          when(
            () => mockStickerPackRepository.loadStickerPacks(),
          ).thenAnswer((_) async => [testPack1, testPack2]);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StickerPacksLoadRequested()),
        expect: () => [
          isA<StickerPickerLoading>(),
          isA<StickerPickerLoaded>()
              .having((s) => s.packs, 'packs', hasLength(2))
              .having(
                (s) => s.filteredStickers,
                'filteredStickers',
                hasLength(3),
              ),
        ],
      );

      blocTest<StickerPickerBloc, StickerPickerState>(
        'emits [loading, error] with loadFailed type on exception',
        setUp: () {
          when(
            () => mockStickerPackRepository.loadStickerPacks(),
          ).thenThrow(Exception('Network error'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StickerPacksLoadRequested()),
        expect: () => [
          isA<StickerPickerLoading>(),
          isA<StickerPickerError>().having(
            (s) => s.errorType,
            'errorType',
            equals(StickerPickerErrorType.loadFailed),
          ),
        ],
      );

      blocTest<StickerPickerBloc, StickerPickerState>(
        'loaded state contains all stickers from all packs '
        'in filteredStickers',
        setUp: () {
          when(
            () => mockStickerPackRepository.loadStickerPacks(),
          ).thenAnswer((_) async => [testPack1, testPack2]);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const StickerPacksLoadRequested()),
        expect: () => [
          isA<StickerPickerLoading>(),
          isA<StickerPickerLoaded>().having(
            (s) => s.filteredStickers.map((st) => st.shortcode).toList(),
            'shortcodes',
            containsAll(['fire', 'thumbs-up', 'cat']),
          ),
        ],
      );
    });

    group('StickerSearchChanged', () {
      blocTest<StickerPickerBloc, StickerPickerState>(
        'filters stickers by shortcode (case-insensitive contains)',
        seed: () => StickerPickerLoaded(
          packs: const [testPack1, testPack2],
          filteredStickers: [
            ...testPack1.stickers,
            ...testPack2.stickers,
          ],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const StickerSearchChanged('FIR')),
        expect: () => [
          isA<StickerPickerLoaded>()
              .having(
                (s) => s.filteredStickers,
                'filteredStickers',
                hasLength(1),
              )
              .having(
                (s) => s.filteredStickers.first.shortcode,
                'shortcode',
                equals('fire'),
              )
              .having(
                (s) => s.searchQuery,
                'searchQuery',
                equals('fir'),
              ),
        ],
      );

      blocTest<StickerPickerBloc, StickerPickerState>(
        'empty query resets to all stickers',
        seed: () => const StickerPickerLoaded(
          packs: [testPack1, testPack2],
          filteredStickers: [],
          searchQuery: 'old-query',
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const StickerSearchChanged('')),
        expect: () => [
          isA<StickerPickerLoaded>()
              .having(
                (s) => s.filteredStickers,
                'filteredStickers',
                hasLength(3),
              )
              .having((s) => s.searchQuery, 'searchQuery', isEmpty),
        ],
      );

      blocTest<StickerPickerBloc, StickerPickerState>(
        'no-op when state is not loaded',
        build: buildBloc,
        act: (bloc) => bloc.add(const StickerSearchChanged('fire')),
        expect: () => <StickerPickerState>[],
      );
    });
  });
}
