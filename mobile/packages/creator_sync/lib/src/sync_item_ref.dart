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
  /// Matching is allowlist-based rather than prefix-based. The
  /// subscription that feeds this also receives foreign kind-30078 events
  /// — notably `dm_repository`'s read-state cursors and this package's own
  /// vault key event — and treating any of them as an item would corrupt
  /// unrelated state.
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
