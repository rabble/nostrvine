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
/// Each emission carries a monotonically increasing [actionId] so that
/// consecutive identical results are always treated as distinct by
/// [BlocListener.listenWhen].
sealed class ShareSheetActionResult extends Equatable {
  const ShareSheetActionResult({required this.actionId});

  /// Monotonically increasing counter — ensures two back-to-back identical
  /// results are never equal, so [BlocListener.listenWhen] always fires.
  final int actionId;
}

class ShareSheetSendSuccess extends ShareSheetActionResult {
  const ShareSheetSendSuccess(
    this.recipientName, {
    required super.actionId,
    this.shouldDismiss = false,
  });

  final String recipientName;

  /// Whether the UI should dismiss the sheet after this success.
  /// True for send-with-message, false for quick-send.
  final bool shouldDismiss;

  @override
  List<Object?> get props => [actionId, recipientName, shouldDismiss];
}

class ShareSheetSendFailure extends ShareSheetActionResult {
  const ShareSheetSendFailure({required super.actionId});

  @override
  List<Object?> get props => [actionId];
}

/// Consolidates the former ShareSheetSaveSuccess and ShareSheetSaveFailure
/// into a single class, using [succeeded] to distinguish the outcome.
class ShareSheetSaveResult extends ShareSheetActionResult {
  const ShareSheetSaveResult({
    required super.actionId,
    required this.succeeded,
  });

  final bool succeeded;

  @override
  List<Object?> get props => [actionId, succeeded];
}

/// Generic failure for utility actions (copy link, share via, etc.).
/// Error details are logged by the BLoC; the UI shows a generic message.
class ShareSheetActionFailure extends ShareSheetActionResult {
  const ShareSheetActionFailure({required super.actionId});

  @override
  List<Object?> get props => [actionId];
}

class ShareSheetCopiedToClipboard extends ShareSheetActionResult {
  const ShareSheetCopiedToClipboard({
    required super.actionId,
    required this.label,
    required this.text,
  });

  /// Human-readable label for the snackbar message.
  final String label;

  /// Text to copy to clipboard.
  final String text;

  @override
  List<Object?> get props => [actionId, label, text];
}

class ShareSheetShareViaTriggered extends ShareSheetActionResult {
  const ShareSheetShareViaTriggered(this.shareText, {required super.actionId});

  /// Text to pass to the platform share sheet.
  final String shareText;

  @override
  List<Object?> get props => [actionId, shareText];
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
