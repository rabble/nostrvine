part of 'badge_editor_cubit.dart';

/// Lifecycle of the badge editor form.
enum BadgeEditorStatus {
  /// Nothing has been requested yet.
  initial,

  /// An existing badge is being loaded into the form.
  loading,

  /// The form is editable.
  ready,

  /// The existing badge could not be loaded.
  loadFailure,

  /// The definition is being published.
  saving,

  /// The definition was published.
  saved,

  /// The definition could not be published.
  saveFailure,
}

/// Status of the staged badge artwork upload.
enum BadgeArtworkStatus {
  /// No upload is running.
  idle,

  /// Artwork is uploading to Blossom.
  uploading,

  /// The upload failed.
  failure,
}

/// State for the [BadgeEditorCubit].
class BadgeEditorState extends Equatable {
  /// Creates badge editor state.
  const BadgeEditorState({
    required this.isEditing,
    this.status = BadgeEditorStatus.initial,
    this.artworkStatus = BadgeArtworkStatus.idle,
    this.name = '',
    this.identifier = '',
    this.identifierEdited = false,
    this.description = '',
    this.imageUrl = '',
    this.thumbnailUrl = '',
    this.submitAttempted = false,
    this.takenIdentifiers = const {},
    this.savedCoordinate,
  });

  /// Whether the form edits an existing badge rather than creating one.
  final bool isEditing;

  /// Current form lifecycle status.
  final BadgeEditorStatus status;

  /// Current artwork upload status.
  final BadgeArtworkStatus artworkStatus;

  /// Display name of the badge.
  final String name;

  /// The definition's `d` identifier.
  final String identifier;

  /// Whether the user typed their own identifier.
  final bool identifierEdited;

  /// Free-text description shown to recipients.
  final String description;

  /// Staged artwork URL.
  final String imageUrl;

  /// Separate thumbnail URL carried over from an existing badge.
  final String thumbnailUrl;

  /// Whether the user has pressed Publish at least once.
  ///
  /// Gates the missing-artwork message, so an empty form does not open
  /// already scolding the user for something they have not skipped yet.
  final bool submitAttempted;

  /// Identifiers already used by the current user's badges.
  ///
  /// Empty while editing, and empty when the lookup failed — in both cases
  /// there is nothing to warn about.
  final Set<String> takenIdentifiers;

  /// Address of the badge once it has been published.
  final BadgeCoordinate? savedCoordinate;

  /// Whether publishing would replace one of the user's existing badges.
  ///
  /// Definitions are addressable, so a reused identifier overwrites rather
  /// than adds — including for people already holding an award for it. The
  /// deliberate way to do that is Edit, not New.
  bool get isIdentifierTaken =>
      !isEditing && takenIdentifiers.contains(identifier.trim());

  /// Whether the written fields are filled in.
  ///
  /// Publish stays pressable on this alone: artwork is the one requirement
  /// reported on submit rather than by a dead button.
  bool get hasRequiredText =>
      name.trim().isNotEmpty && identifier.trim().isNotEmpty;

  /// Whether the form carries everything a definition needs.
  ///
  /// Artwork counts: a badge without an image renders as a bare initial
  /// everywhere it appears, so the editor does not let one be published.
  bool get isValid =>
      hasRequiredText && imageUrl.isNotEmpty && !isIdentifierTaken;

  /// Whether to tell the user that artwork is still missing.
  bool get showArtworkRequired => submitAttempted && imageUrl.isEmpty;

  /// Whether an action that owns the whole form is in flight.
  ///
  /// Gates the artwork and Publish controls: a second upload would race the
  /// first, and Publish mid-upload would report artwork as missing while it
  /// is on its way.
  bool get isBusy =>
      isPublishing || artworkStatus == BadgeArtworkStatus.uploading;

  /// Whether the definition is being published right now.
  ///
  /// The text fields lock on this alone — an artwork upload runs in the
  /// background and must not stop the user from finishing the rest of the
  /// form while it does.
  bool get isPublishing => status == BadgeEditorStatus.saving;

  /// Returns a copy with selected fields replaced.
  BadgeEditorState copyWith({
    BadgeEditorStatus? status,
    BadgeArtworkStatus? artworkStatus,
    String? name,
    String? identifier,
    bool? identifierEdited,
    String? description,
    String? imageUrl,
    String? thumbnailUrl,
    bool? submitAttempted,
    Set<String>? takenIdentifiers,
    BadgeCoordinate? savedCoordinate,
  }) {
    return BadgeEditorState(
      isEditing: isEditing,
      status: status ?? this.status,
      artworkStatus: artworkStatus ?? this.artworkStatus,
      name: name ?? this.name,
      identifier: identifier ?? this.identifier,
      identifierEdited: identifierEdited ?? this.identifierEdited,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      submitAttempted: submitAttempted ?? this.submitAttempted,
      takenIdentifiers: takenIdentifiers ?? this.takenIdentifiers,
      savedCoordinate: savedCoordinate ?? this.savedCoordinate,
    );
  }

  @override
  List<Object?> get props => [
    isEditing,
    status,
    artworkStatus,
    name,
    identifier,
    identifierEdited,
    description,
    imageUrl,
    thumbnailUrl,
    submitAttempted,
    takenIdentifiers,
    savedCoordinate,
  ];
}
