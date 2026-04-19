// ABOUTME: Cubit for managing the app's display locale
// ABOUTME: Reads/writes via LocalePreferenceService, emits Locale? state

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/locale_preference_service.dart';

part 'locale_state.dart';

/// Manages the app's display locale.
///
/// Emits [LocaleState] with a [Locale] when the user has chosen a specific
/// language, or `null` when following the device default.
class LocaleCubit extends Cubit<LocaleState> {
  /// Creates a [LocaleCubit] backed by [localePreferenceService].
  LocaleCubit({
    required LocalePreferenceService localePreferenceService,
  }) : _service = localePreferenceService,
       super(const LocaleState()) {
    _loadSavedLocale();
  }

  final LocalePreferenceService _service;

  void _loadSavedLocale() {
    final saved = _service.getLocale();
    if (saved != null) {
      emit(LocaleState(locale: Locale(saved)));
    }
  }

  /// Sets the app locale to [localeCode] (e.g. `'es'`, `'tr'`).
  Future<void> setLocale(String localeCode) async {
    await _service.setLocale(localeCode);
    emit(LocaleState(locale: Locale(localeCode)));
  }

  /// Clears the custom locale, reverting to device default.
  Future<void> clearLocale() async {
    await _service.clearLocale();
    emit(const LocaleState());
  }
}
