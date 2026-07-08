// ABOUTME: Real ProtectedMinorInboxGate (#176) — composes the protected-minor
// ABOUTME: status with OfficialAccountsService: a restricted minor sees only
// ABOUTME: all-approved conversations, and each pass kicks receive-time
// ABOUTME: revalidation so a server-side revocation drops the counterparty.

import 'dart:async';

import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/services/official_accounts_service.dart';

class ProtectedMinorInboxGateImpl implements ProtectedMinorInboxGate {
  ProtectedMinorInboxGateImpl({
    required bool Function() isRestricted,
    required OfficialAccountsService officials,
  }) : _isRestricted = isRestricted,
       _officials = officials;

  final bool Function() _isRestricted;
  final OfficialAccountsService _officials;

  /// A verdict flip persisted by [OfficialAccountsService] re-fires the list so
  /// the sync filter re-evaluates with the fresh answer.
  @override
  Stream<void> get changes => _officials.onVerdictChanged;

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    if (!_isRestricted()) return conversations;

    final visible = <DmConversation>[];
    for (final c in conversations) {
      var allApproved = true;
      for (final p in c.participantPubkeys) {
        if (p == userPubkey) continue;
        // Receive-time revalidation (fire-and-forget): refresh the verdict so a
        // server-side revocation is pulled into the sync answer; the async
        // method re-resolves only when the cached verdict is stale. A resulting
        // flip fires onVerdictChanged -> the list re-filters and this
        // counterparty drops.
        unawaited(_officials.isApprovedMinorDmRecipient(p));
        if (!_officials.isApprovedMinorDmRecipientSync(p)) {
          allApproved = false;
        }
      }
      if (allApproved) visible.add(c);
    }
    return visible;
  }
}
