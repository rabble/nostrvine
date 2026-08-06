part of 'avatar_svg_cubit.dart';

enum AvatarSvgStatus { initial, loading, ready, unavailable }

const _avatarSvgBytesUnset = Object();

class AvatarSvgState extends Equatable {
  const AvatarSvgState({this.status = AvatarSvgStatus.initial, this.bytes});

  final AvatarSvgStatus status;
  final Uint8List? bytes;

  AvatarSvgState copyWith({
    AvatarSvgStatus? status,
    Object? bytes = _avatarSvgBytesUnset,
  }) {
    return AvatarSvgState(
      status: status ?? this.status,
      bytes: identical(bytes, _avatarSvgBytesUnset)
          ? this.bytes
          : bytes as Uint8List?,
    );
  }

  @override
  List<Object?> get props => [status, bytes];
}
