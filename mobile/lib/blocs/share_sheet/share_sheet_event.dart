// ABOUTME: Events for ShareSheetBloc
// ABOUTME: Handles contact loading, recipient selection, and share actions

part of 'share_sheet_bloc.dart';

/// Base class for share sheet events.
sealed class ShareSheetEvent extends Equatable {
  const ShareSheetEvent();

  @override
  List<Object?> get props => [];
}

/// Request to load contacts (recent + followed users).
///
/// Dispatched on BLoC creation to populate the contact list.
class ShareSheetContactsLoadRequested extends ShareSheetEvent {
  const ShareSheetContactsLoadRequested();
}

/// A contact was tapped for quick-send (no message).
class ShareSheetQuickSendRequested extends ShareSheetEvent {
  const ShareSheetQuickSendRequested(this.recipient);

  final ShareableUser recipient;

  @override
  List<Object?> get props => [recipient.pubkey];
}

/// A recipient was selected (from Find People or contact tap for message).
class ShareSheetRecipientSelected extends ShareSheetEvent {
  const ShareSheetRecipientSelected(this.recipient);

  final ShareableUser recipient;

  @override
  List<Object?> get props => [recipient.pubkey];
}

/// Recipient selection was cleared.
class ShareSheetRecipientCleared extends ShareSheetEvent {
  const ShareSheetRecipientCleared();
}

/// Send video with an optional message to the selected recipient.
class ShareSheetSendRequested extends ShareSheetEvent {
  const ShareSheetSendRequested({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

/// Save video to bookmarks.
class ShareSheetSaveRequested extends ShareSheetEvent {
  const ShareSheetSaveRequested();
}

/// Add a classic Vine to the local clip library.
class ShareSheetAddClassicVineToClipsRequested extends ShareSheetEvent {
  const ShareSheetAddClassicVineToClipsRequested();
}

/// Copy share link to clipboard.
class ShareSheetCopyLinkRequested extends ShareSheetEvent {
  const ShareSheetCopyLinkRequested();
}

/// Share externally via platform share sheet.
class ShareSheetShareViaRequested extends ShareSheetEvent {
  const ShareSheetShareViaRequested();
}

/// Copy event JSON to clipboard.
class ShareSheetCopyEventJsonRequested extends ShareSheetEvent {
  const ShareSheetCopyEventJsonRequested();
}

/// Copy event ID (nevent) to clipboard.
class ShareSheetCopyEventIdRequested extends ShareSheetEvent {
  const ShareSheetCopyEventIdRequested();
}
