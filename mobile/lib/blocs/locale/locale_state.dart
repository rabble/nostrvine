// ABOUTME: State for the LocaleCubit — holds the user's chosen app locale
// ABOUTME: null locale means "use device default"

part of 'locale_cubit.dart';

/// State for [LocaleCubit].
///
/// [locale] is `null` when the user has not overridden the device default.
class LocaleState extends Equatable {
  /// Creates a [LocaleState].
  const LocaleState({this.locale});

  /// The user-selected locale, or `null` for device default.
  final Locale? locale;

  @override
  List<Object?> get props => [locale];
}
