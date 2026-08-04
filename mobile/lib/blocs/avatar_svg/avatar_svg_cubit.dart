// ABOUTME: Cubit for loading validated remote SVG avatar bytes.
// ABOUTME: Keeps UserAvatar rendering state separate from repository/network work.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/repositories/avatar_svg_repository.dart';
import 'package:unified_logger/unified_logger.dart';

part 'avatar_svg_state.dart';

class AvatarSvgCubit extends Cubit<AvatarSvgState> {
  AvatarSvgCubit({required AvatarSvgRepository repository, required String url})
    : _repository = repository,
      _url = url,
      super(const AvatarSvgState());

  final AvatarSvgRepository _repository;
  final String _url;

  Future<void> load() async {
    if (state.status == AvatarSvgStatus.loading) return;

    emit(state.copyWith(status: AvatarSvgStatus.loading));
    try {
      final bytes = await _repository.load(_url);
      if (bytes == null) {
        emit(state.copyWith(status: AvatarSvgStatus.unavailable));
        return;
      }
      emit(state.copyWith(status: AvatarSvgStatus.ready, bytes: bytes));
    } on Object catch (error, stackTrace) {
      Log.error(
        'Avatar SVG load failed',
        name: 'AvatarSvgCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      emit(state.copyWith(status: AvatarSvgStatus.unavailable));
    }
  }
}
