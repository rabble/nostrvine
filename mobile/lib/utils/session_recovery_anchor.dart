import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Returns true when [candidatePubkey] belongs to a different account than
/// the one recorded in [anchorNpub] at sign-out time.
///
/// Returns false (no block) when either side is absent — if there is no anchor
/// or the session has no bound pubkey, the guard degrades gracefully rather
/// than breaking the normal single-account flow.
bool isCrossAccountSessionRestore({
  required String? candidatePubkey,
  required String? anchorNpub,
}) {
  if (anchorNpub == null || candidatePubkey == null) return false;
  final candidateNpub = NostrKeyUtils.encodePubKey(candidatePubkey);
  if (anchorNpub == candidateNpub) return false;

  Log.warning(
    'initialize: cross-account session restore blocked — '
    'anchor=$anchorNpub, candidate=$candidateNpub. '
    'Routing to unauthenticated for explicit confirmation.',
    name: 'AuthService',
    category: LogCategory.auth,
  );
  return true;
}
