part of 'avatar_svg_cubit.dart';

enum AvatarSvgStatus { initial, loading, ready, unavailable }

class AvatarSvgState extends Equatable {
  const AvatarSvgState({this.status = AvatarSvgStatus.initial, this.bytes});

  final AvatarSvgStatus status;
  final Uint8List? bytes;

  AvatarSvgState copyWith({AvatarSvgStatus? status, Uint8List? bytes}) {
    return AvatarSvgState(
      status: status ?? this.status,
      bytes: bytes ?? this.bytes,
    );
  }

  @override
  List<Object?> get props => [status, bytes];
}
