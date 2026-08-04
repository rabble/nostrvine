import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/avatar_svg/avatar_svg_cubit.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';

void main() {
  const url = 'https://divine.video/avatar.svg';
  final bytes = Uint8List.fromList(
    utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" />'),
  );

  group(AvatarSvgCubit, () {
    blocTest<AvatarSvgCubit, AvatarSvgState>(
      'emits ready when repository returns bytes',
      build: () =>
          AvatarSvgCubit(repository: _FakeAvatarSvgRepository(bytes), url: url),
      act: (cubit) => cubit.load(),
      expect: () => [
        const AvatarSvgState(status: AvatarSvgStatus.loading),
        AvatarSvgState(status: AvatarSvgStatus.ready, bytes: bytes),
      ],
    );

    blocTest<AvatarSvgCubit, AvatarSvgState>(
      'emits unavailable when repository returns null',
      build: () => AvatarSvgCubit(
        repository: const _FakeAvatarSvgRepository(null),
        url: url,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const AvatarSvgState(status: AvatarSvgStatus.loading),
        const AvatarSvgState(status: AvatarSvgStatus.unavailable),
      ],
    );
  });
}

class _FakeAvatarSvgRepository implements AvatarSvgRepository {
  const _FakeAvatarSvgRepository(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> load(String url) async => bytes;
}
