// ABOUTME: Data Access Object for user profile operations with domain
// ABOUTME: model conversion. Provides upsert from UserProfile model.
// ABOUTME: Simple CRUD is in AppDbClient.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:models/models.dart';

part 'user_profiles_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfilesDaoMixin {
  UserProfilesDao(super.attachedDatabase);

  /// Upsert profile from domain model, keeping the newest version.
  ///
  /// Converts a [UserProfile] domain model to a database companion and writes
  /// it only when it should win over the currently-cached row for the same
  /// pubkey. Newest-wins is applied here — at the single write chokepoint —
  /// so every caller (relay event routing, REST caching, direct cache writes)
  /// is protected from a stale or blank kind-0 clobbering a good cached
  /// profile, without each caller having to guard on its own.
  ///
  /// Replacement rule for an incoming profile vs the existing row:
  /// - no existing row: insert;
  /// - incoming is newer (`createdAt` later): replace;
  /// - incoming is older: keep the existing row untouched;
  /// - same `createdAt`: replace only when the incoming profile is *richer*
  ///   (more non-empty identity fields), which breaks ties toward the more
  ///   complete profile. A genuine field clear rides in on a strictly newer
  ///   event, so it still applies.
  ///
  /// The read and the conditional write run in a transaction so concurrent
  /// writers cannot race between the compare and the write.
  ///
  /// For simple CRUD operations (get, watch, delete), use AppDbClient instead.
  Future<void> upsertProfile(UserProfile profile) {
    return transaction(() async {
      final existing = await getProfile(profile.pubkey);
      if (existing != null && !_incomingWins(profile, existing)) {
        return;
      }
      await into(userProfiles).insertOnConflictUpdate(
        UserProfilesCompanion.insert(
          pubkey: profile.pubkey,
          displayName: Value(profile.displayName),
          name: Value(profile.name),
          about: Value(profile.about),
          picture: Value(profile.picture),
          banner: Value(profile.banner),
          website: Value(profile.website),
          nip05: Value(profile.nip05),
          lud16: Value(profile.lud16),
          lud06: Value(profile.lud06),
          rawData: Value(
            profile.rawData.isNotEmpty ? jsonEncode(profile.rawData) : null,
          ),
          createdAt: profile.createdAt,
          eventId: profile.eventId,
          lastFetched: DateTime.now(),
        ),
      );
    });
  }

  /// Whether [incoming] should replace [existing] under the newest-wins rule
  /// documented on [upsertProfile].
  static bool _incomingWins(UserProfile incoming, UserProfile existing) {
    if (incoming.createdAt.isAfter(existing.createdAt)) return true;
    if (incoming.createdAt.isBefore(existing.createdAt)) return false;
    return _identityRichness(incoming) > _identityRichness(existing);
  }

  /// Counts the non-empty identity fields on [profile], used only as the
  /// equal-`createdAt` tiebreak in [_incomingWins].
  static int _identityRichness(UserProfile profile) {
    var count = 0;
    if (profile.name?.isNotEmpty ?? false) count++;
    if (profile.displayName?.isNotEmpty ?? false) count++;
    if (profile.picture?.isNotEmpty ?? false) count++;
    if (profile.about?.isNotEmpty ?? false) count++;
    if (profile.banner?.isNotEmpty ?? false) count++;
    return count;
  }

  /// Get a single profile by pubkey with domain model conversion.
  ///
  /// Returns UserProfile domain model or null if not found.
  Future<UserProfile?> getProfile(String pubkey) async {
    final query = select(userProfiles)..where((t) => t.pubkey.equals(pubkey));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _rowToUserProfile(row);
  }

  /// Get all profiles with domain model conversion.
  ///
  /// Returns list of UserProfile domain models sorted by created_at DESC.
  Future<List<UserProfile>> getAllProfiles() async {
    final query = select(userProfiles)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToUserProfile).toList();
  }

  /// Delete a profile by pubkey.
  ///
  /// Returns the number of rows deleted (0 or 1).
  Future<int> deleteProfile(String pubkey) {
    return (delete(userProfiles)..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Watch a single profile by pubkey with domain model conversion.
  ///
  /// Returns a stream that emits UserProfile domain model whenever
  /// the profile changes in the database.
  ///
  /// Drift re-runs a table watcher on *every* write to `user_profiles`, so
  /// without a distinct guard each watcher would re-emit on unrelated profile
  /// writes too — during the cold-start kind-0 flood that fans out into a
  /// rebuild for every author row and caption.
  ///
  /// The dedup key is (pubkey, eventId, createdAt), not `UserProfile` value
  /// equality. `UserProfile.==` is (pubkey, eventId) only, but the Funnelcake
  /// REST path mints a content-independent synthetic eventId (`rest-<pubkey>`),
  /// so a newer profile version can reuse the same eventId. Comparing
  /// [UserProfile.createdAt] too — which the newest-wins cache only ever
  /// advances — keeps a real update flowing through while still collapsing the
  /// no-op re-emissions.
  Stream<UserProfile?> watchProfile(String pubkey) {
    final query = select(userProfiles)..where((t) => t.pubkey.equals(pubkey));
    return query
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToUserProfile(row))
        .distinct(_isSameProfileVersion);
  }

  /// Whether two consecutive [watchProfile] emissions are the same profile
  /// version. Compares `createdAt` on top of `UserProfile.==` — see
  /// [watchProfile] for why the eventId alone is not enough.
  static bool _isSameProfileVersion(UserProfile? a, UserProfile? b) {
    if (a == null || b == null) return identical(a, b);
    return a.pubkey == b.pubkey &&
        a.eventId == b.eventId &&
        a.createdAt == b.createdAt;
  }

  /// Get multiple profiles by pubkeys with domain model conversion.
  ///
  /// Returns a list of UserProfile domain models for the given pubkeys.
  /// Profiles not found in the database are omitted from the result.
  Future<List<UserProfile>> getProfilesByPubkeys(
    List<String> pubkeys,
  ) async {
    if (pubkeys.isEmpty) return [];
    final query = select(userProfiles)..where((t) => t.pubkey.isIn(pubkeys));
    final rows = await query.get();
    return rows.map(_rowToUserProfile).toList();
  }

  /// Batch upsert profiles from domain models.
  ///
  /// Inserts or updates all given profiles in a single batch operation.
  /// Uses a Drift batch for efficiency when writing many profiles at once.
  ///
  /// This is intentionally a blind batch write for uncached bulk imports.
  /// Use [upsertProfile] when writing an already-cached pubkey where
  /// newest-wins clobber protection matters.
  Future<void> upsertProfiles(List<UserProfile> profiles) async {
    if (profiles.isEmpty) return;
    await batch((b) {
      for (final profile in profiles) {
        b.insert(
          userProfiles,
          UserProfilesCompanion.insert(
            pubkey: profile.pubkey,
            displayName: Value(profile.displayName),
            name: Value(profile.name),
            about: Value(profile.about),
            picture: Value(profile.picture),
            banner: Value(profile.banner),
            website: Value(profile.website),
            nip05: Value(profile.nip05),
            lud16: Value(profile.lud16),
            lud06: Value(profile.lud06),
            rawData: Value(
              profile.rawData.isNotEmpty ? jsonEncode(profile.rawData) : null,
            ),
            createdAt: profile.createdAt,
            eventId: profile.eventId,
            lastFetched: DateTime.now(),
          ),
          onConflict: DoUpdate(
            (_) => UserProfilesCompanion(
              displayName: Value(profile.displayName),
              name: Value(profile.name),
              about: Value(profile.about),
              picture: Value(profile.picture),
              banner: Value(profile.banner),
              website: Value(profile.website),
              nip05: Value(profile.nip05),
              lud16: Value(profile.lud16),
              lud06: Value(profile.lud06),
              rawData: Value(
                profile.rawData.isNotEmpty ? jsonEncode(profile.rawData) : null,
              ),
              createdAt: Value(profile.createdAt),
              eventId: Value(profile.eventId),
              lastFetched: Value(DateTime.now()),
            ),
          ),
        );
      }
    });
  }

  /// Watch all profiles with domain model conversion.
  ///
  /// Returns a stream that emits list of UserProfile domain models
  /// whenever any profile changes in the database.
  Stream<List<UserProfile>> watchAllProfiles() {
    final query = select(userProfiles)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToUserProfile).toList());
  }

  /// Convert database row to UserProfile domain model.
  UserProfile _rowToUserProfile(UserProfileRow row) {
    var rawData = <String, dynamic>{};
    if (row.rawData != null) {
      rawData = jsonDecode(row.rawData!) as Map<String, dynamic>;
    }
    return UserProfile(
      pubkey: row.pubkey,
      name: row.name,
      displayName: row.displayName,
      about: row.about,
      picture: row.picture,
      banner: row.banner,
      website: row.website,
      nip05: row.nip05,
      lud16: row.lud16,
      lud06: row.lud06,
      rawData: rawData,
      createdAt: row.createdAt,
      eventId: row.eventId,
    );
  }
}
