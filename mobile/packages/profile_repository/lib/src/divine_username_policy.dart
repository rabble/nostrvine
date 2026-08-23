// ABOUTME: Shared validation for divine.video usernames (single DNS label).

/// Minimum length for a divine.video username (inclusive).
const kDivineUsernameMinLength = 3;

/// Maximum length for a divine.video username (inclusive, DNS label limit).
const kDivineUsernameMaxLength = 63;

final _divineUsernameCharacters = RegExp(r'^[a-z0-9-]+$');

/// Result of calling [validateDivineUsername].
sealed class DivineUsernameValidationResult {
  const DivineUsernameValidationResult();
}

/// Successful validation; [normalized] is lowercased and trimmed input.
final class DivineUsernameValid extends DivineUsernameValidationResult {
  /// Creates a successful validation result.
  const DivineUsernameValid({required this.normalized});

  /// Lowercase trimmed username.
  final String normalized;
}

/// Failed validation with a machine-readable [failure].
final class DivineUsernameInvalid extends DivineUsernameValidationResult {
  /// Creates a failed validation result.
  const DivineUsernameInvalid({required this.failure});

  /// Machine-readable failure that the UI can localize.
  final DivineUsernameValidationFailure failure;
}

/// Why a Divine username failed client-side validation.
enum DivineUsernameValidationFailure {
  /// No username was supplied.
  required,

  /// The username is outside the DNS-label length bounds.
  invalidLength,

  /// A DNS label cannot start or end with a hyphen.
  leadingOrTrailingHyphen,

  /// The username contains characters that are not valid in a DNS label.
  invalidCharacters,
}

/// Lowercase and trim without validating (shared normalization helper).
String normalizeDivineUsernameInput(String input) => input.toLowerCase().trim();

/// Validates a string for use as the label in `_@name.divine.video`.
///
/// Order: empty → length → leading/trailing hyphen → allowed character run.
DivineUsernameValidationResult validateDivineUsername(String input) {
  final normalized = normalizeDivineUsernameInput(input);
  if (normalized.isEmpty) {
    return const DivineUsernameInvalid(
      failure: DivineUsernameValidationFailure.required,
    );
  }
  if (normalized.length < kDivineUsernameMinLength ||
      normalized.length > kDivineUsernameMaxLength) {
    return const DivineUsernameInvalid(
      failure: DivineUsernameValidationFailure.invalidLength,
    );
  }
  if (normalized.startsWith('-') || normalized.endsWith('-')) {
    return const DivineUsernameInvalid(
      failure: DivineUsernameValidationFailure.leadingOrTrailingHyphen,
    );
  }
  if (!_divineUsernameCharacters.hasMatch(normalized)) {
    return const DivineUsernameInvalid(
      failure: DivineUsernameValidationFailure.invalidCharacters,
    );
  }
  return DivineUsernameValid(normalized: normalized);
}
