import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the user's appearance selection and applies it for the current run.
class AppearanceCubit extends Cubit<AppearanceMode> {
  AppearanceCubit(this._repository) : super(AppearanceMode.system);

  final AppearanceRepository _repository;

  Future<void> load() async {
    emit(await _repository.load());
  }

  Future<void> setMode(AppearanceMode mode) async {
    emit(mode);
    try {
      await _repository.save(mode);
    } catch (error) {
      Log.warning(
        'Failed to persist appearance preference: $error',
        name: 'AppearanceCubit',
        category: LogCategory.system,
      );
    }
  }
}

ThemeMode resolveThemeMode({
  required AppearanceMode mode,
  required bool lightModeEnabled,
  required Brightness systemBrightness,
}) {
  if (!lightModeEnabled) return ThemeMode.dark;

  return switch (mode) {
    AppearanceMode.system =>
      systemBrightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };
}
