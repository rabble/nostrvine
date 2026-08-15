// ABOUTME: Cubit for loading validated remote SVG avatar bytes.
// ABOUTME: Keeps UserAvatar rendering state separate from repository/network work.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'avatar_svg_state.dart';

class AvatarSvgCubit extends Cubit<AvatarSvgState>
    with CloseGuardedEmit<AvatarSvgState> {
  AvatarSvgCubit({required AvatarSvgRepository repository, required String url})
    : _repository = repository,
      _url = url,
      super(const AvatarSvgState());

  final AvatarSvgRepository _repository;
  final String _url;

  Future<void> load() async {
    if (isClosed || state.status == AvatarSvgStatus.loading) return;

    emitIfOpen(state.copyWith(status: AvatarSvgStatus.loading));
    try {
      final bytes = await _repository.load(_url);
      if (isClosed) return;

      if (bytes == null) {
        emitIfOpen(
          state.copyWith(status: AvatarSvgStatus.unavailable, bytes: null),
        );
        return;
      }
      emitIfOpen(state.copyWith(status: AvatarSvgStatus.ready, bytes: bytes));
    } on Object catch (error, stackTrace) {
      if (isClosed) return;

      Log.error(
        'Avatar SVG load failed',
        name: 'AvatarSvgCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(status: AvatarSvgStatus.unavailable, bytes: null),
      );
    }
  }
}
