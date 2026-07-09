// ABOUTME: Shared #176 access predicate: may a DM-restricted user (protected
// ABOUTME: minor) see a conversation with these counterparties? Fail-closed.

/// Whether a DM-restricted user may access a conversation with
/// [participantPubkeys] (#176). Requires at least one counterparty AND that
/// every counterparty is an approved official: an empty list is a degenerate
/// route and must fail closed rather than pass the vacuous truth of
/// `[].every(...)`.
///
/// Shared by the conversation route guard ([ConversationPage]) and the
/// message-request preview gate ([RequestPreviewCubit]) so the two entry
/// points cannot drift apart.
bool allParticipantsApprovedForMinor(
  List<String> participantPubkeys,
  bool Function(String) isApproved,
) => participantPubkeys.isNotEmpty && participantPubkeys.every(isApproved);
