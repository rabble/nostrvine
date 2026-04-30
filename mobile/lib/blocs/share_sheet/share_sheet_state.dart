// ABOUTME: State for ShareSheetBloc
// ABOUTME: Tracks contacts, selected recipient, sending status, and action results

part of 'share_sheet_bloc.dart';

/// Status of the share sheet.
enum ShareSheetStatus {
  /// Initial state before contacts are loaded.
  initial,

  /// Contacts are being loaded.
  loading,

  /// Contacts loaded, ready for interaction.
  ready,
}

/// One-shot action result communicated via [ShareSheetState.actionResult].
///
/// Consumed by BlocListener to show snackbars or dismiss the sheet.
/// Constructors are intentionally **non-const** so that each instance has
/// a unique identity.  Since this hierarchy does not extend [Equatable],
/// identity equality ensures that consecutive identical-looking results
/// are always treated as distinct by [BlocListener.listenWhen] and by
/// [Bloc.emit]'s state-deduplication check inside [ShareSheetState].
sealed class ShareSheetActionResult {
  ShareSheetActionResult();
}

class ShareSheetSendSuccess extends ShareSheetActionResult {
  ShareSheetSendSuccess(this.recipientName, {this.shouldDismiss = false});

  final String recipientName;

  /// Whether the UI should dismiss the sheet after this success.
  /// True for send-with-message, false for quick-send.
  final bool shouldDismiss;
}

class ShareSheetSendFailure extends ShareSheetActionResult {
  ShareSheetSendFailure();
}

/// Consolidates the former ShareSheetSaveSuccess and ShareSheetSaveFailure
/// into a single class, using [succeeded] to distinguish the outcome.
///
/// When [succeeded] is true, [removed] tells the UI whether the video was
/// removed from global bookmarks (toggle off) vs added (toggle on).
///
/// [wasBookmarkedBeforeToggle] is set for every attempt. When [succeeded]
/// is false, the UI uses it to show an add-specific vs remove-specific error.
class ShareSheetSaveResult extends ShareSheetActionResult {
  ShareSheetSaveResult({
    required this.succeeded,
    this.removed = false,
    this.wasBookmarkedBeforeToggle = false,
  });

  final bool succeeded;

  /// Meaningful only when [succeeded] is true: user turned the bookmark off.
  final bool removed;

  /// Whether the video was already globally bookmarked before this toggle.
  final bool wasBookmarkedBeforeToggle;
}

class ShareSheetClassicVineClipImportResult extends ShareSheetActionResult {
  ShareSheetClassicVineClipImportResult({required this.succeeded});

  final bool succeeded;
}

/// Generic failure for utility actions (copy link, share via, etc.).
/// Error details are logged by the BLoC; the UI shows a generic message.
class ShareSheetActionFailure extends ShareSheetActionResult {
  ShareSheetActionFailure();
}

class ShareSheetCopiedToClipboard extends ShareSheetActionResult {
  ShareSheetCopiedToClipboard({required this.label, required this.text});

  /// Human-readable label for the snackbar message.
  final String label;

  /// Text to copy to clipboard.
  final String text;
}

class ShareSheetShareViaTriggered extends ShareSheetActionResult {
  ShareSheetShareViaTriggered({
    required this.shareUrl,
    this.thumbnailPath,
    this.title,
    this.subject,
  });

  /// The share URL to pass as text to the platform share sheet.
  final String shareUrl;

  /// Local file path of the downloaded thumbnail image, or `null` if
  /// the download failed or no thumbnail was available.
  final String? thumbnailPath;

  /// Video title used as the share sheet title / Android `EXTRA_TITLE`.
  final String? title;

  /// Video title used as email subject where supported.
  final String? subject;
}

/// State for the share sheet.
class ShareSheetState extends Equatable {
  const ShareSheetState({
    this.status = ShareSheetStatus.initial,
    this.contacts = const [],
    this.selectedRecipient,
    this.sentPubkeys = const {},
    this.isSending = false,
    this.actionResult,
  });

  /// Current loading status.
  final ShareSheetStatus status;

  /// Loaded contacts (recent + followed users).
  final List<ShareableUser> contacts;

  /// Currently selected recipient for message-send flow.
  final ShareableUser? selectedRecipient;

  /// Pubkeys that have already been sent to (quick-send).
  final Set<String> sentPubkeys;

  /// Whether a send operation is in progress.
  final bool isSending;

  /// One-shot action result for BlocListener consumption.
  /// Cleared on next state emission.
  final ShareSheetActionResult? actionResult;

  /// Whether contacts have finished loading.
  bool get contactsLoaded => status == ShareSheetStatus.ready;

  ShareSheetState copyWith({
    ShareSheetStatus? status,
    List<ShareableUser>? contacts,
    ShareableUser? selectedRecipient,
    Set<String>? sentPubkeys,
    bool? isSending,
    ShareSheetActionResult? actionResult,
    bool clearRecipient = false,
    bool clearActionResult = false,
  }) {
    return ShareSheetState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      selectedRecipient: clearRecipient
          ? null
          : (selectedRecipient ?? this.selectedRecipient),
      sentPubkeys: sentPubkeys ?? this.sentPubkeys,
      isSending: isSending ?? this.isSending,
      actionResult: clearActionResult
          ? null
          : (actionResult ?? this.actionResult),
    );
  }

  @override
  List<Object?> get props => [
    status,
    contacts,
    selectedRecipient,
    sentPubkeys,
    isSending,
    actionResult,
  ];
}
