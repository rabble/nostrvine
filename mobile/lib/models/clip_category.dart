// ABOUTME: A user-created category that files clips in the clip library.
// ABOUTME: Mirrors the Drift clip_categories row without exposing db_client.

import 'package:equatable/equatable.dart';

/// A category the user created to organize their library clips.
///
/// The library's built-in All, Archive, and Deleted filters are not
/// categories and have no instance here — see `ClipLibraryFilter`.
class ClipCategory extends Equatable {
  const ClipCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    this.orderIndex = 0,
  });

  /// Unique category identifier.
  final String id;

  /// The user's own display name for this category. Never localized.
  final String name;

  /// When the user created the category.
  final DateTime createdAt;

  /// Position in the library's chip row, ascending.
  final int orderIndex;

  /// Longest name a category may carry. Keeps a single chip from swallowing
  /// the whole row and the name readable in the move-to sheet.
  static const maxNameLength = 40;

  /// Trims [rawName] and returns it, or `null` when it holds no usable text.
  /// Callers use `null` to reject the input instead of creating a category
  /// with a blank or whitespace-only name.
  static String? sanitizeName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= maxNameLength
        ? trimmed
        : trimmed.substring(0, maxNameLength);
  }

  ClipCategory copyWith({String? name, int? orderIndex}) {
    return ClipCategory(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, orderIndex];
}
