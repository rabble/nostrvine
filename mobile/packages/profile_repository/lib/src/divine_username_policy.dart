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

/// Failed validation with a human-readable [reason].
final class DivineUsernameInvalid extends DivineUsernameValidationResult {
  /// Creates a failed validation result.
  const DivineUsernameInvalid({required this.reason});

  /// Human-readable failure reason.
  final String reason;
}

/// Lowercase and trim without validating (shared normalization helper).
String normalizeDivineUsernameInput(String input) => input.toLowerCase().trim();

/// Validates a string for use as the label in `_@name.divine.video`.
///
/// Order: empty → length → leading/trailing hyphen → allowed character run.
DivineUsernameValidationResult validateDivineUsername(String input) {
  final normalized = normalizeDivineUsernameInput(input);
  if (normalized.isEmpty) {
    return const DivineUsernameInvalid(reason: 'Username is required');
  }
  if (normalized.length < kDivineUsernameMinLength ||
      normalized.length > kDivineUsernameMaxLength) {
    return const DivineUsernameInvalid(
      reason:
          'Usernames must be '
          '$kDivineUsernameMinLength–$kDivineUsernameMaxLength characters',
    );
  }
  if (normalized.startsWith('-') || normalized.endsWith('-')) {
    return const DivineUsernameInvalid(
      reason: "Usernames can't start or end with a hyphen",
    );
  }
  if (!_divineUsernameCharacters.hasMatch(normalized)) {
    return const DivineUsernameInvalid(
      reason:
          'Only letters, numbers, and hyphens are allowed '
          '(your username becomes username.divine.video)',
    );
  }
  return DivineUsernameValid(normalized: normalized);
}
