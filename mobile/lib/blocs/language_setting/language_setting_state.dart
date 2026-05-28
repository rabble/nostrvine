// ABOUTME: State for LanguageSettingCubit — content-language preference
// ABOUTME: snapshot. `currentCode` is whatever the service is currently
// ABOUTME: resolving to (custom override or device default).

import 'package:equatable/equatable.dart';

/// Load lifecycle of the language-setting tile.
enum LanguageSettingStatus { loading, ready }

/// State for `LanguageSettingCubit`.
class LanguageSettingState extends Equatable {
  const LanguageSettingState({
    this.status = LanguageSettingStatus.loading,
    this.currentCode = '',
    this.isCustomLanguageSet = false,
  });

  final LanguageSettingStatus status;

  /// ISO-639-1 code currently in effect (custom override or device default).
  final String currentCode;

  /// Whether the user has overridden the device default with a custom pick.
  final bool isCustomLanguageSet;

  LanguageSettingState copyWith({
    LanguageSettingStatus? status,
    String? currentCode,
    bool? isCustomLanguageSet,
  }) {
    return LanguageSettingState(
      status: status ?? this.status,
      currentCode: currentCode ?? this.currentCode,
      isCustomLanguageSet: isCustomLanguageSet ?? this.isCustomLanguageSet,
    );
  }

  @override
  List<Object?> get props => [status, currentCode, isCustomLanguageSet];
}
