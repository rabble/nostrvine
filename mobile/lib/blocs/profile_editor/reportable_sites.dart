// ABOUTME: Per-feature Reportable `context:` constants for ProfileEditorBloc.
// ABOUTME: See .claude/rules/error_handling.md — once a feature accumulates 2+
// ABOUTME: Reportable-wrapped call sites, the identifiers lift here.

/// Stable `context:` identifiers for `Reportable(...)` wraps inside
/// [ProfileEditorBloc].
///
/// Per the convention in `.claude/rules/error_handling.md`, when a Bloc
/// has more than one `addError(Reportable(e, context: ...))` site, the
/// `context:` strings are lifted into a per-feature constants class so
/// the Crashlytics dashboard groups them by stable identifier rather
/// than inline string literals.
abstract class ProfileEditorReportableSites {
  /// `_onProfileSaved` outer wrap — any `Error` (StateError, TypeError,
  /// RangeError) that escapes the repository's `on Exception` swallow in
  /// `claimUsername` or the synchronous pre-publish transforms.
  static const String onProfileSaved = '_onProfileSaved';

  /// `_onProfileNip05Saved` outer wrap — same coverage as [onProfileSaved],
  /// dispatched from the dedicated NIP-05 entry point.
  static const String onProfileNip05Saved = '_onProfileNip05Saved';

  /// `_onProfileSaveConfirmed` outer wrap — same coverage as [onProfileSaved],
  /// dispatched after the blank-profile-overwrite confirmation dialog.
  static const String onProfileSaveConfirmed = '_onProfileSaveConfirmed';

  /// `_onUsernameChanged` outer wrap — `checkUsernameAvailability` catches
  /// `on Exception` and returns a typed `UsernameCheckError`, but `Error`
  /// subclasses (a JSON decode `TypeError`, an unexpected `StateError`)
  /// escape past that filter.
  static const String onUsernameChanged = '_onUsernameChanged';

  /// `_onUsernameRechecked` outer wrap — same `Error`-escape contract as
  /// [onUsernameChanged], dispatched from the reserved-recheck CTA.
  static const String onUsernameRechecked = '_onUsernameRechecked';

  /// Narrowed publish-path catch in `_saveProfile`: any non-typed throw
  /// (drift `TypeError` from a schema mismatch, `StateError` from a sync
  /// transform between `saveProfileEvent` and `cacheProfile`) that escapes
  /// the typed `on NoRelaysConnectedException` / `on ProfilePublishFailedException`
  /// branches.
  static const String saveProfilePublish = '_saveProfile';

  /// `_canonicalizeProfileAbout` — `MentionResolutionService` catches
  /// `on Exception` internally; only `Error` subtypes (StateError from
  /// `_applyReplacements`, RangeError on substring edges, TypeError from
  /// API-shape casts) escape here. The save continues with the unresolved
  /// `rawAbout`.
  static const String canonicalizeProfileAbout = '_canonicalizeProfileAbout';
}
