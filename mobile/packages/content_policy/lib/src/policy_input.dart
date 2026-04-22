/// Minimal input the policy engine needs to evaluate a single event.
///
/// Parsers construct this from the raw JSON envelope of a Nostr event
/// (or a REST response row that carries the same fields). Only [pubkey]
/// is consulted by the Phase 1 rules; the remaining fields are part of
/// the contract so future rules (hashtag, keyword) can be added without
/// changing every call site.
class PolicyInput {
  /// Creates a [PolicyInput] with the given event fields.
  const PolicyInput({
    required this.pubkey,
    this.kind,
    this.content,
    this.tags,
  });

  /// Event author's hex pubkey. Required.
  final String pubkey;

  /// Event kind (NIP-01 integer). Optional — not all REST responses carry it.
  final int? kind;

  /// Event content string. Optional.
  final String? content;

  /// Event tags, as the standard `List<List<String>>` NIP-01 shape. Optional.
  final List<List<String>>? tags;
}
