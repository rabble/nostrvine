// ABOUTME: Formats and parses the d tags identifying synced items.
// ABOUTME: Allowlist parsing keeps foreign kind-30078 events out.

import 'package:meta/meta.dart';

/// The collections creator sync mirrors across devices.
enum SyncItemKind {
  /// A saved reusable sound.
  sound,

  /// A standalone library clip.
  clip,

  /// A video draft.
  draft,
}

/// Identifies one synced item by kind and id.
@immutable
class SyncItemRef {
  /// Creates a [SyncItemRef].
  const SyncItemRef(this.kind, this.id);

  /// Shared prefix for every creator-sync `d` tag.
  static const String prefix = 'divine:sync:';

  /// The collection this item belongs to.
  final SyncItemKind kind;

  /// The item's full, untruncated identifier.
  final String id;

  /// The `d` tag value for this item's addressable event.
  String get dTag => '$prefix${kind.name}:$id';

  /// Parses [dTag], returning null when it is not a creator-sync item.
  ///
  /// Matching is allowlist-based rather than prefix-based. The query behind
  /// this cannot filter on `d` (item tags are per-item and unenumerable), so
  /// it returns every kind-30078 event this account has ever published —
  /// this package's own vault-key event, plus whatever any other app the
  /// user runs stores under the shared app-specific-data kind. Treating one
  /// of those as a sound would corrupt unrelated state.
  ///
  /// `dm_repository`'s read cursors are not among them: those are kind-30078
  /// *rumors* sealed inside NIP-59 gift wraps, so on a relay they are
  /// kind-1059 events and never match this filter.
  static SyncItemRef? tryParse(String dTag) {
    if (!dTag.startsWith(prefix)) return null;

    final remainder = dTag.substring(prefix.length);
    final separator = remainder.indexOf(':');
    if (separator <= 0) return null;

    final kindName = remainder.substring(0, separator);
    final id = remainder.substring(separator + 1);
    if (id.isEmpty) return null;

    for (final kind in SyncItemKind.values) {
      if (kind.name == kindName) return SyncItemRef(kind, id);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncItemRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'SyncItemRef($dTag)';
}
