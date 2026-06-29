import 'package:equatable/equatable.dart';

/// Display text with per-locale translations.
///
/// Values are keyed by BCP-47 language code (e.g. `en`, `de`, `ja`).
/// Resolution falls back to [fallbackLocaleCode] (English) and then to the
/// first available value, so a missing translation degrades gracefully
/// instead of throwing or rendering a blank.
class LocalizedText extends Equatable {
  /// Creates a [LocalizedText] from a map of language code to text.
  const LocalizedText(this.values);

  /// Creates a [LocalizedText] holding a single [value] under the
  /// [fallbackLocaleCode] (English).
  factory LocalizedText.single(String value) =>
      LocalizedText({fallbackLocaleCode: value});

  /// Builds a [LocalizedText] from JSON.
  ///
  /// Accepts either:
  /// - a `String` — treated as the English fallback value. This keeps older
  ///   serialized data (where the text was a plain string) deserializable.
  /// - a `Map` of language code to text.
  ///
  /// Any other shape yields an empty [LocalizedText].
  factory LocalizedText.fromJson(Object? json) {
    if (json is String) return LocalizedText.single(json);
    if (json is Map) {
      return LocalizedText(
        json.map((key, value) => MapEntry(key as String, value as String)),
      );
    }
    return const LocalizedText({});
  }

  /// Language code used as the fallback when a requested locale is missing.
  static const fallbackLocaleCode = 'en';

  /// Translations keyed by BCP-47 language code.
  final Map<String, String> values;

  /// Resolves the text for [localeCode], falling back to English and then to
  /// the first available value. Returns an empty string when no value exists.
  String resolve(String localeCode) {
    return values[localeCode] ??
        values[fallbackLocaleCode] ??
        (values.isEmpty ? '' : values.values.first);
  }

  /// The English fallback value (or the first available value), regardless of
  /// the active locale.
  String get fallback => resolve(fallbackLocaleCode);

  /// Converts this [LocalizedText] to JSON.
  ///
  /// Serializes to a plain `String` when only the English fallback is present,
  /// keeping serialized payloads (e.g. draft layer metadata) compact and
  /// backward-compatible with the plain-string format.
  Object toJson() {
    if (values.length == 1 && values.containsKey(fallbackLocaleCode)) {
      return values[fallbackLocaleCode]!;
    }
    return values;
  }

  @override
  List<Object?> get props => [values];
}
