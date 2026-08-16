// ABOUTME: Measured on-disk footprint of every directory the app writes to.
// ABOUTME: Lives in the model layer so the developer diagnostic UI can read it
// ABOUTME: without importing the service that produces it.

import 'package:equatable/equatable.dart';
import 'package:openvine/utils/byte_size_format.dart';

/// One immediate child of a measured footprint root.
class StorageFootprintEntry extends Equatable {
  /// Creates an entry.
  const StorageFootprintEntry({
    required this.name,
    required this.bytes,
    required this.isDirectory,
  });

  /// Entry name, relative to its root.
  final String name;

  /// Bytes held by this entry — recursive when it is a directory.
  final int bytes;

  /// Whether this entry is a directory.
  final bool isDirectory;

  @override
  List<Object?> get props => [name, bytes, isDirectory];
}

/// One root directory of the app's on-disk footprint.
class StorageFootprintRoot extends Equatable {
  /// Creates a measured root.
  const StorageFootprintRoot({
    required this.label,
    required this.path,
    required this.totalBytes,
    required this.largestChildren,
    required this.childCount,
  });

  /// Which platform directory this is, e.g. `Documents`.
  final String label;

  /// Absolute path on this device.
  final String path;

  /// Bytes held by the whole subtree.
  final int totalBytes;

  /// The biggest immediate children, largest first.
  final List<StorageFootprintEntry> largestChildren;

  /// How many immediate children the root has in total.
  ///
  /// [largestChildren] keeps only the biggest, so without this a reader
  /// cannot tell whether the listed entries add up to [totalBytes] or
  /// whether the rest is spread across entries that were left out.
  final int childCount;

  /// Bytes held by the children [largestChildren] left out.
  int get omittedBytes =>
      totalBytes - largestChildren.fold(0, (sum, child) => sum + child.bytes);

  /// How many children [largestChildren] left out.
  int get omittedCount => childCount - largestChildren.length;

  @override
  List<Object?> get props => [
    label,
    path,
    totalBytes,
    largestChildren,
    childCount,
  ];
}

/// The app's full on-disk footprint, split by root directory.
class StorageFootprint extends Equatable {
  /// Creates a footprint.
  const StorageFootprint({required this.roots});

  /// Nothing measured yet.
  static const empty = StorageFootprint(roots: []);

  /// Every root the app writes to, in measurement order.
  final List<StorageFootprintRoot> roots;

  /// Bytes across all roots.
  int get totalBytes => roots.fold(0, (sum, root) => sum + root.totalBytes);

  /// A plain-text report for pasting into a support thread.
  ///
  /// Deliberately unlocalized: it is read by whoever triages the report, not
  /// by the user, and mixed-locale reports are harder to compare. Raw byte
  /// counts sit alongside the readable size so a report stays sortable.
  String toReportText() {
    final buffer = StringBuffer()
      ..writeln('Divine storage footprint')
      ..writeln('Total: ${formatByteSize(totalBytes)} ($totalBytes bytes)');
    for (final root in roots) {
      buffer
        ..writeln()
        ..writeln(
          '${root.label}: ${formatByteSize(root.totalBytes)} '
          '(${root.totalBytes} bytes)',
        )
        ..writeln('  path: ${root.path}');
      if (root.largestChildren.isEmpty) {
        buffer.writeln('  (empty)');
        continue;
      }
      for (final child in root.largestChildren) {
        final suffix = child.isDirectory ? '/' : '';
        buffer.writeln(
          '  ${formatByteSize(child.bytes)}\t${child.name}$suffix',
        );
      }
      // Only the biggest children are listed, so say what the rest holds —
      // otherwise the entries above look like they should add up to the
      // root total and the difference reads as a measurement bug.
      if (root.omittedCount > 0) {
        buffer.writeln(
          '  ${formatByteSize(root.omittedBytes)}\t'
          '(${root.omittedCount} smaller entries not listed)',
        );
      }
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [roots];
}
