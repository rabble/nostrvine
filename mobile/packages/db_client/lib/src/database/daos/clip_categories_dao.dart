// ABOUTME: DAO for the user-created categories that file library clips.
// ABOUTME: Provides CRUD plus per-account isolation via ownerPubkey.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'clip_categories_dao.g.dart';

@DriftAccessor(tables: [ClipCategories, Clips])
class ClipCategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$ClipCategoriesDaoMixin {
  ClipCategoriesDao(super.attachedDatabase);

  /// Build a filter expression that returns rows owned by [ownerPubkey]
  /// **or** legacy rows with no owner (NULL).
  Expression<bool> _ownedOrLegacy(String? ownerPubkey) {
    if (ownerPubkey == null) return const Constant(true);
    return clipCategories.ownerPubkey.equals(ownerPubkey) |
        clipCategories.ownerPubkey.isNull();
  }

  /// Get all categories in chip-row order, oldest-created first within the
  /// same order index. When [ownerPubkey] is provided, returns only
  /// categories owned by that account **plus** legacy rows with no owner.
  Future<List<ClipCategoryRow>> getCategories({String? ownerPubkey}) {
    final query = select(clipCategories)
      ..where((_) => _ownedOrLegacy(ownerPubkey))
      ..orderBy([
        (t) => OrderingTerm(expression: t.orderIndex),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    return query.get();
  }

  /// Get a single category by ID, or `null` when it no longer exists.
  Future<ClipCategoryRow?> getCategoryById(String id) {
    return (select(
      clipCategories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert a category, or update it when [id] already exists.
  Future<void> upsertCategory({
    required String id,
    required String name,
    required DateTime createdAt,
    int orderIndex = 0,
    String? ownerPubkey,
  }) {
    return into(clipCategories).insertOnConflictUpdate(
      ClipCategoriesCompanion.insert(
        id: id,
        name: name,
        createdAt: createdAt,
        orderIndex: Value(orderIndex),
        ownerPubkey: Value(ownerPubkey),
      ),
    );
  }

  /// Rename an existing category.
  ///
  /// Returns true if a row was updated.
  Future<bool> renameCategory({
    required String id,
    required String name,
  }) async {
    final rows =
        await (update(
          clipCategories,
        )..where((t) => t.id.equals(id))).write(
          ClipCategoriesCompanion(name: Value(name)),
        );
    return rows > 0;
  }

  /// Delete the category [id] and unfile every clip that referenced it.
  ///
  /// The clips themselves are kept — they fall back to the library's default
  /// view. Both writes run in one transaction so a category can never
  /// disappear while clips still point at it.
  ///
  /// Returns true if the category existed.
  Future<bool> deleteCategory(String id) {
    return transaction(() async {
      await (update(clips)..where((t) => t.categoryId.equals(id))).write(
        const ClipsCompanion(categoryId: Value(null)),
      );
      final rows = await (delete(
        clipCategories,
      )..where((t) => t.id.equals(id))).go();
      return rows > 0;
    });
  }

  /// The highest [ClipCategories.orderIndex] currently in use, or `null`
  /// when the account has no categories yet. Callers append after it.
  Future<int?> highestOrderIndex({String? ownerPubkey}) async {
    final maxOrder = clipCategories.orderIndex.max();
    final query = selectOnly(clipCategories)
      ..where(_ownedOrLegacy(ownerPubkey))
      ..addColumns([maxOrder]);
    final row = await query.getSingleOrNull();
    return row?.read(maxOrder);
  }

  /// Delete all categories owned by [userPubkey], unfiling their clips.
  ///
  /// Legacy categories with NULL ownerPubkey are preserved because they
  /// cannot be attributed to any specific account. Used on destructive
  /// sign-out to prevent cross-account data leaks.
  Future<int> deleteAllForUser(String userPubkey) {
    return transaction(() async {
      final owned = await (select(
        clipCategories,
      )..where((t) => t.ownerPubkey.equals(userPubkey))).get();
      if (owned.isNotEmpty) {
        final ownedIds = [for (final category in owned) category.id];
        await (update(clips)..where((t) => t.categoryId.isIn(ownedIds))).write(
          const ClipsCompanion(categoryId: Value(null)),
        );
      }
      return (delete(
        clipCategories,
      )..where((t) => t.ownerPubkey.equals(userPubkey))).go();
    });
  }

  /// Claim legacy categories (NULL ownerPubkey) or rows owned by the optional
  /// [sourceOwnerPubkey] marker for [newOwnerPubkey].
  ///
  /// Mirrors `ClipsDao.claimLegacyRows` so categories created before sign-in
  /// follow the clips they file into the signing-in account.
  Future<int> claimLegacyRows(
    String newOwnerPubkey, {
    String? sourceOwnerPubkey,
  }) {
    return (update(clipCategories)..where(
          (t) => sourceOwnerPubkey == null
              ? t.ownerPubkey.isNull()
              : t.ownerPubkey.isNull() |
                    t.ownerPubkey.equals(sourceOwnerPubkey),
        ))
        .write(ClipCategoriesCompanion(ownerPubkey: Value(newOwnerPubkey)));
  }
}
